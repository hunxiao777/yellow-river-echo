import test from 'node:test';
import assert from 'node:assert/strict';
import { AuthCore } from './auth-core.mjs';
function fixture(sender) {
  let now = 1000000, sent = '';
  const core = new AuthCore({ secret:'test-only-secret-with-at-least-32-characters', now:() => now,
    sendSms:sender || (async (_phone,code) => { sent = code; }) });
  return { core, code:() => sent, advance:n => { now += n; } };
}
test('SMS response never contains OTP; correct code creates one-use session',async () => {
  const f=fixture(); const r=await f.core.send('13800000000','test');
  assert.equal(r.retryAfter,60); assert.ok(!JSON.stringify(r).includes(f.code()));
  const session=f.core.verify('13800000000',f.code(),'test');
  assert.equal(f.core.me(session.token).nick,'续响者');
  assert.throws(() => f.core.verify('13800000000',f.code(),'test'));
  assert.throws(() => f.core.me('invented-token')); f.core.db.close();
});
test('expired OTP and five wrong guesses are rejected',async () => {
  const f=fixture(); await f.core.send('13800000000','test');
  const wrong = f.code() === '123456' ? '654321' : '123456';
  for(let i=0;i<5;i++) assert.throws(() => f.core.verify('13800000000',wrong,'test'));
  assert.throws(() => f.core.verify('13800000000',f.code(),'test'));
  f.advance(61000); await f.core.send('13800000000','test'); f.advance(300001);
  assert.throws(() => f.core.verify('13800000000',f.code(),'test')); f.core.db.close();
});
test('concurrent sends are reserved before awaiting SMS provider',async () => {
  let complete; const f=fixture(() => new Promise(r => {complete=r;}));
  const first=f.core.send('13800000000','test');
  await assert.rejects(f.core.send('13800000000','test'),{status:429});
  complete(); await first; f.core.db.close();
});
test('provider failure cannot produce a verifiable OTP',async () => {
  const f=fixture(async () => { throw new Error('provider rejected'); });
  await assert.rejects(f.core.send('13800000000','test'),{status:503});
  assert.throws(() => f.core.verify('13800000000','123456','test')); f.core.db.close();
});
test('OAuth state binds provider, cannot be replayed, ticket is single-use',() => {
  const f=fixture(); const {state,ticket}=f.core.oauthStart('qq');
  assert.throws(() => f.core.oauthClaim(state,'wechat'));
  assert.equal(f.core.oauthPoll(ticket).status,'pending');
  f.core.oauthClaim(state,'qq'); assert.throws(() => f.core.oauthClaim(state,'qq'));
  f.core.oauthFinish(state,'qq:app:person');
  assert.ok(f.core.oauthPoll(ticket).token);
  assert.throws(() => f.core.oauthPoll(ticket)); f.core.db.close();
});
