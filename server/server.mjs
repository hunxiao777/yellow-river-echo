import http from 'node:http';
import { AuthCore, AuthError } from './auth-core.mjs';
import { aliyunReady, sendAliyunSms } from './aliyun-sms.mjs';
const env = process.env;
const publicBase = (env.PUBLIC_BASE_URL || '').replace(/\/$/, '');
const providers = {
  wechat: { id: env.WECHAT_APP_ID, secret: env.WECHAT_APP_SECRET },
  qq: { id: env.QQ_APP_ID, secret: env.QQ_APP_SECRET }
};
const smsReady = () => env.SMS_PROVIDER === 'tencent'
  ? ['TENCENT_SECRET_ID','TENCENT_SECRET_KEY','SMS_APP_ID','SMS_SIGN_NAME','SMS_TEMPLATE_ID'].every(key => env[key])
  : aliyunReady(env);
async function sendSms(phone, code) {
  if (!smsReady()) throw new Error('SMS not configured');
  if (env.SMS_PROVIDER !== 'tencent') return sendAliyunSms(env,phone,code);
  const sdk = (await import('tencentcloud-sdk-nodejs')).default;
  const client = new sdk.sms.v20210111.Client({
    credential: { secretId: env.TENCENT_SECRET_ID, secretKey: env.TENCENT_SECRET_KEY },
    region: env.SMS_REGION || 'ap-guangzhou', profile: { httpProfile: { reqTimeout: 10 } }
  });
  const result = await client.SendSms({ PhoneNumberSet: ['+86' + phone], SmsSdkAppId: env.SMS_APP_ID,
    SignName: env.SMS_SIGN_NAME, TemplateId: env.SMS_TEMPLATE_ID, TemplateParamSet: [code, '5'] });
  if (result.SendStatusSet?.[0]?.Code !== 'Ok') throw new Error('SMS provider rejected');
}
const core = new AuthCore({ database: env.DATABASE || 'auth.sqlite', secret: env.AUTH_SECRET, sendSms });
function providerConfig(name) {
  const p = Object.hasOwn(providers,name) && providers[name];
  if (!p || !p.id || !p.secret || !publicBase.startsWith('https://')) throw new AuthError('该登录渠道尚未开通，请使用手机号或离线体验', 503);
  return p;
}
async function getJSON(url) {
  const r = await fetch(url, { signal: AbortSignal.timeout(10000), redirect: 'error' });
  if (!r.ok) throw new Error('Provider unavailable');
  return r.json();
}
async function exchange(provider, code) {
  const p = providerConfig(provider);
  if (provider === 'wechat') {
    const q = new URLSearchParams({ appid:p.id, secret:p.secret, code, grant_type:'authorization_code' });
    const data = await getJSON('https://api.weixin.qq.com/sns/oauth2/access_token?' + q);
    if (data.errcode || !data.openid || !data.access_token) throw new Error('Invalid OAuth code');
    return 'wechat:' + p.id + ':' + data.openid;
  }
  const q = new URLSearchParams({ client_id:p.id, client_secret:p.secret, code,
    grant_type:'authorization_code', redirect_uri:publicBase+'/auth/oauth/callback/qq', fmt:'json' });
  const data = await getJSON('https://graph.qq.com/oauth2.0/token?' + q);
  if (!data.access_token) throw new Error('Invalid OAuth code');
  const identity = await getJSON('https://graph.qq.com/oauth2.0/me?' + new URLSearchParams({ access_token:data.access_token, fmt:'json' }));
  if (!identity.openid || identity.client_id !== p.id) throw new Error('Invalid OAuth audience');
  return 'qq:' + p.id + ':' + identity.openid;
}
async function body(req) {
  let input = '';
  for await (const chunk of req) { input += chunk; if (Buffer.byteLength(input) > 4096) throw new AuthError('请求过大',413); }
  try { return JSON.parse(input || '{}'); } catch { throw new AuthError('请求格式错误'); }
}
function json(res,status,data) { res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}); res.end(JSON.stringify(data)); }
http.createServer(async (req,res) => {
  try {
    const path = new URL(req.url,'http://localhost');
    // Do not trust user-supplied X-Forwarded-For. Reverse proxy must rate-limit client IP too.
    const ip = req.socket.remoteAddress || 'unknown';
    if (req.method === 'GET' && path.pathname === '/health') return json(res,200,{ ok:true, smsConfigured:smsReady() });
    if (req.method === 'GET' && path.pathname === '/auth/me') return json(res,200,core.me((req.headers.authorization || '').replace(/^Bearer /,'')));
    if (req.method === 'GET' && /^\/auth\/oauth\/callback\/(wechat|qq)$/.test(path.pathname)) {
      const provider = path.pathname.split('/').pop(), state = path.searchParams.get('state') || '';
      core.oauthClaim(state,provider);
      try {
        const code = path.searchParams.get('code');
        if (!code || code.length > 512) throw new Error('No authorization code');
        core.oauthFinish(state,await exchange(provider,code));
      } catch { core.oauthFinish(state,''); throw new AuthError('授权未完成，请返回应用重试'); }
      res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer'});
      return res.end('<!doctype html><meta name="viewport" content="width=device-width"><title>黄河续响</title><p>授权已完成，请返回黄河续响应用。</p>');
    }
    if (req.method !== 'POST') throw new AuthError('接口不存在',404);
    const data = await body(req);
    if (path.pathname === '/auth/sms/send') {
      if (!smsReady()) throw new AuthError('短信服务尚未开通，请先配置服务端短信签名和模板',503);
      return json(res,200,await core.send(data.phone,ip));
    }
    if (path.pathname === '/auth/sms/verify') return json(res,200,core.verify(data.phone,data.code,ip));
    if (path.pathname === '/auth/oauth/start') {
      core.limit('oauth:'+ip,20,60000);
      const p = providerConfig(data.provider), {state,ticket} = core.oauthStart(data.provider);
      const redirect = publicBase+'/auth/oauth/callback/'+data.provider;
      const url = data.provider === 'wechat'
        ? 'https://open.weixin.qq.com/connect/qrconnect?' + new URLSearchParams({appid:p.id,redirect_uri:redirect,response_type:'code',scope:'snsapi_login',state}) + '#wechat_redirect'
        : 'https://graph.qq.com/oauth2.0/authorize?' + new URLSearchParams({client_id:p.id,redirect_uri:redirect,response_type:'code',scope:'get_user_info',state,display:'mobile'});
      return json(res,200,{ticket,authorizationUrl:url});
    }
    if (path.pathname === '/auth/oauth/poll') {
      core.limit('poll:'+ip,120,60000);
      return json(res,200,core.oauthPoll(data.ticket));
    }
    throw new AuthError('接口不存在',404);
  } catch (error) {
    json(res,error instanceof AuthError ? error.status : 503,{message:error instanceof AuthError ? error.message : '服务暂不可用，请稍后重试'});
  }
}).listen(Number(env.PORT || 8787),env.HOST || '127.0.0.1',() => console.log('Auth service listening; OTPs and credentials are never logged.'));
