import test from 'node:test';
import assert from 'node:assert/strict';
import {sendAliyunSms,aliyunReady} from './aliyun-sms.mjs';
const env={ALIYUN_ACCESS_KEY_ID:'test',ALIYUN_ACCESS_KEY_SECRET:'test',ALIYUN_SMS_SIGN_NAME:'test',ALIYUN_SMS_TEMPLATE_CODE:'test'};
test('missing configuration cannot send',async()=>{
  assert.equal(aliyunReady({}),false);
  await assert.rejects(sendAliyunSms({},'13800000000','123456',()=>{throw Error('must not call');}));
});
test('PNVS sends supplied OTP for local one-use verification',async()=>{
  await sendAliyunSms(env,'13800000000','123456',async(action,p)=>{
    assert.equal(action,'SendSmsVerifyCode');assert.equal(JSON.parse(p.TemplateParam).code,'123456');
    assert.equal(p.ReturnVerifyCode,false);assert.equal(p.ValidTime,300);return {Code:'OK',Success:true};
  });
});
test('provider rejection is not reported as success',async()=>{
  await assert.rejects(sendAliyunSms(env,'13800000000','123456',async()=>({Code:'Forbidden',Success:false})));
});
