// PNVS SMS API; the existing AuthCore generates and verifies the supplied code.
export const aliyunReady = (env) => ['ALIYUN_ACCESS_KEY_ID','ALIYUN_ACCESS_KEY_SECRET','ALIYUN_SMS_SIGN_NAME','ALIYUN_SMS_TEMPLATE_CODE'].every(k => Boolean(env[k]?.trim()));
export function smsParams(env, phone, code) {
  if (!/^1[3-9]\d{9}$/.test(phone) || !/^\d{6}$/.test(code)) throw new Error('Invalid SMS parameters');
  return {
    PhoneNumber: phone, CountryCode: '86',
    SignName: env.ALIYUN_SMS_SIGN_NAME, TemplateCode: env.ALIYUN_SMS_TEMPLATE_CODE,
    TemplateParam: JSON.stringify({code, min:'5'}),
    SchemeName: env.ALIYUN_SMS_SCHEME_NAME || '黄河续响',
    ValidTime:300, Interval:60, ReturnVerifyCode:false
  };
}
export async function sendAliyunSms(env,phone,code,request) {
  if (!aliyunReady(env)) throw new Error('Aliyun SMS configuration missing');
  if (!request) {
    const RPCClient = (await import('@alicloud/pop-core')).default;
    const client = new RPCClient({accessKeyId:env.ALIYUN_ACCESS_KEY_ID,
      accessKeySecret:env.ALIYUN_ACCESS_KEY_SECRET,
      endpoint:'https://dypnsapi.aliyuncs.com',apiVersion:'2017-05-25'});
    request=(action,params)=>client.request(action,params,{method:'POST',timeout:10000});
  }
  const result=await request('SendSmsVerifyCode',smsParams(env,phone,code));
  if (result.Code !== 'OK' || result.Success === false) throw new Error('Aliyun SMS request rejected');
}
