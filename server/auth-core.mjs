import { randomInt, randomBytes, createHmac, createHash, timingSafeEqual } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
export class AuthError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}
export class AuthCore {
  constructor({ database = ':memory:', secret, sendSms, now = Date.now }) {
    if (!secret || secret.length < 32) throw new Error('AUTH_SECRET must contain at least 32 characters');
    this.secret = secret; this.sendSms = sendSms; this.now = now;
    this.db = new DatabaseSync(database);
    this.db.exec(`PRAGMA journal_mode=WAL;
      CREATE TABLE IF NOT EXISTS codes(phone TEXT PRIMARY KEY, digest TEXT, expires INTEGER, attempts INTEGER, sent INTEGER);
      CREATE TABLE IF NOT EXISTS quota(key TEXT PRIMARY KEY, count INTEGER, expires INTEGER);
      CREATE TABLE IF NOT EXISTS sessions(digest TEXT PRIMARY KEY, subject TEXT, expires INTEGER);
      CREATE TABLE IF NOT EXISTS oauth(state TEXT PRIMARY KEY, ticket TEXT UNIQUE, provider TEXT, expires INTEGER, status TEXT, subject TEXT);`);
  }
  phone(raw) { if (typeof raw !== 'string' || !/^1[3-9]\d{9}$/.test(raw)) throw new AuthError('请输入正确的中国大陆手机号'); return raw; }
  hash(value) { return createHash('sha256').update(value).digest('hex'); }
  digest(phone, code) { return createHmac('sha256', this.secret).update(phone + ':' + code).digest('hex'); }
  limit(key, max, period) {
    const n = this.now();
    const row = this.db.prepare('SELECT * FROM quota WHERE key=?').get(key);
    if (row && row.expires > n && row.count >= max) throw new AuthError('操作过于频繁，请稍后重试', 429);
    this.db.prepare('INSERT OR REPLACE INTO quota VALUES(?,?,?)').run(key, row && row.expires > n ? row.count + 1 : 1, row && row.expires > n ? row.expires : n + period);
  }
  async send(raw, ip) {
    const phone = this.phone(raw), n = this.now();
    this.db.prepare('DELETE FROM quota WHERE expires < ?').run(n);
    this.db.prepare('DELETE FROM codes WHERE expires < ? AND sent < ?').run(n, n - 60000);
    const last = this.db.prepare('SELECT sent FROM codes WHERE phone=?').get(phone);
    if (last && n - last.sent < 60000) throw new AuthError('请等待 60 秒后重新发送', 429);
    this.limit('sms-ip:' + ip, 10, 3600000);
    this.limit('sms-phone:' + phone, 10, 86400000);
    const code = String(randomInt(100000, 1000000));
    // Reserve before awaiting provider, preventing concurrent sends for one phone.
    this.db.prepare('INSERT OR REPLACE INTO codes VALUES(?,?,?,?,?)').run(phone, '', n + 300000, 0, n);
    try {
      await this.sendSms(phone, code);
      this.db.prepare('UPDATE codes SET digest=? WHERE phone=? AND sent=?').run(this.digest(phone, code), phone, n);
    } catch (error) {
      this.db.prepare('DELETE FROM codes WHERE phone=? AND sent=?').run(phone, n);
      throw new AuthError('短信服务未开通或发送失败，请稍后重试', 503);
    }
    return { message: '验证码已发送', retryAfter: 60 };
  }
  verify(raw, code, ip) {
    const phone = this.phone(raw);
    this.limit('verify-ip:' + ip, 30, 60000);
    if (typeof code !== 'string' || !/^\d{6}$/.test(code)) throw new AuthError('请输入六位验证码');
    const row = this.db.prepare('SELECT * FROM codes WHERE phone=?').get(phone);
    if (!row || !row.digest || row.expires <= this.now() || row.attempts >= 5) throw new AuthError('验证码已失效，请重新获取');
    this.db.prepare('UPDATE codes SET attempts=attempts+1 WHERE phone=?').run(phone);
    if (!timingSafeEqual(Buffer.from(row.digest), Buffer.from(this.digest(phone, code)))) throw new AuthError('验证码不正确');
    this.db.prepare('DELETE FROM codes WHERE phone=?').run(phone);
    return this.session('phone:' + phone);
  }
  session(subject) {
    const token = randomBytes(32).toString('base64url');
    this.db.prepare('DELETE FROM sessions WHERE expires < ?').run(this.now());
    this.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(this.hash(token), subject, this.now() + 7 * 86400000);
    return { token, nick: '续响者' };
  }
  me(token) {
    const row = this.db.prepare('SELECT subject FROM sessions WHERE digest=? AND expires>?').get(this.hash(token), this.now());
    if (!row) throw new AuthError('登录已过期，请重新登录', 401);
    return { nick: '续响者' };
  }
  oauthStart(provider) {
    this.db.prepare('DELETE FROM oauth WHERE expires < ?').run(this.now());
    const state = randomBytes(24).toString('base64url'), ticket = randomBytes(32).toString('base64url');
    this.db.prepare('INSERT INTO oauth VALUES(?,?,?,?,?,?)').run(state, this.hash(ticket), provider, this.now() + 300000, 'pending', '');
    return { state, ticket };
  }
  oauthClaim(state, provider) {
    const row = this.db.prepare('SELECT * FROM oauth WHERE state=? AND provider=? AND expires>? AND status=?').get(state, provider, this.now(), 'pending');
    if (!row) throw new AuthError('授权已过期或已使用');
    this.db.prepare('UPDATE oauth SET status=? WHERE state=?').run('processing',state);
  }
  oauthFinish(state, subject) { this.db.prepare('UPDATE oauth SET status=?,subject=? WHERE state=?').run(subject ? 'complete' : 'failed',subject || '',state); }
  oauthPoll(ticket) {
    if (typeof ticket !== 'string' || ticket.length > 128) throw new AuthError('无效授权请求');
    const digest = this.hash(ticket);
    const row = this.db.prepare('SELECT * FROM oauth WHERE ticket=? AND expires>?').get(digest, this.now());
    if (!row) throw new AuthError('授权已过期，请重试');
    if (row.status === 'failed') throw new AuthError('第三方授权未完成，请重试');
    if (row.status !== 'complete') return { status: 'pending' };
    this.db.prepare('DELETE FROM oauth WHERE ticket=?').run(digest);
    return { status: 'complete', ...this.session(row.subject) };
  }
}
