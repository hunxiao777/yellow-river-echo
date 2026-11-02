// 注册用的手机号验证码闸门。
//
// 真接短信通道要三样东西凑齐：云账号 AccessKey、审核通过的签名与模板、一个公网可达的服务端。
// 链路是 App 用 HTTPS 请求自己的服务端，服务端再拿 AccessKey 调网关 —— AccessKey 绝不能下发到客户端，
// 谁反编译谁就能拿这个号去给别人发短信。这个工程目前一行网络代码都没有，所以这里走本机演示通道：
// 码在本机生成、本机校验，界面上只写「本次验证码 + 有效期」。哪天要换真网关，只把 issue() 里生成码那一行
// 换成一次 HTTPS 请求，倒计时、有效期、错次上限这些规则一行都不用动。
export class VerifyGate {
  private static readonly inst: VerifyGate = new VerifyGate();

  static get(): VerifyGate {
    return VerifyGate.inst;
  }

  // 5 分钟内有效，60 秒才让重发，连错三次这条就作废
  static readonly TTL_MS: number = 5 * 60 * 1000;
  static readonly RESEND_MS: number = 60 * 1000;
  static readonly MAX_TRIES: number = 3;

  private phone: string = '';
  private code: string = '';
  private sentAt: number = 0;
  private tries: number = 0;

  // 只留数字，把「+86 138-1234-5678」这类输入洗成纯号码
  static digits(raw: string): string {
    let out = '';
    for (let i = 0; i < raw.length; i++) {
      let c = raw.charCodeAt(i);
      if (c >= 48 && c <= 57) {
        out += raw.charAt(i);
      }
    }
    return out;
  }

  // 返回 '' 表示号码看着是对的，否则是能直接弹给用户的中文原因
  static phoneErr(raw: string): string {
    let p = VerifyGate.digits(raw);
    if (p.length === 0) {
      return '填一下手机号';
    }
    if (p.length !== 11) {
      return '手机号得是 11 位';
    }
    if (p.charAt(0) !== '1' || p.charAt(1) < '3' || p.charAt(1) > '9') {
      return '这个号段不像手机号';
    }
    return '';
  }

  // 本机只留这个掩码，完整号码不落盘
  static mask(p: string): string {
    return p.substring(0, 3) + '****' + p.substring(7);
  }

  // 当前还有效的那条码，过期或作废返回 ''。界面拿它常驻显示，免得靠一闪而过的 toast 读码
  peek(): string {
    if (this.code.length === 0) {
      return '';
    }
    if (Date.now() - this.sentAt > VerifyGate.TTL_MS) {
      return '';
    }
    if (this.tries >= VerifyGate.MAX_TRIES) {
      return '';
    }
    return this.code;
  }

  // 距离下一次能发还剩几秒，0 表示现在就能发
  secondsLeft(): number {
    if (this.code.length === 0) {
      return 0;
    }
    let gap = Date.now() - this.sentAt;
    if (gap >= VerifyGate.RESEND_MS) {
      return 0;
    }
    return Math.ceil((VerifyGate.RESEND_MS - gap) / 1000);
  }

  // 生成并返回这条演示码 —— 调用方要把它显示出来，不然没人知道该输什么
  issue(raw: string): string {
    this.phone = VerifyGate.digits(raw);
    this.code = String(Math.floor(100000 + Math.random() * 900000));
    this.sentAt = Date.now();
    this.tries = 0;
    return this.code;
  }

  private dead(): void {
    this.phone = '';
    this.code = '';
    this.sentAt = 0;
    this.tries = 0;
  }

  // 返回 '' 表示校验通过。注意这条码通过或作废后都会被清掉，所以调用方要把它放在所有格式校验之后
  verify(raw: string, input: string): string {
    if (this.code.length === 0) {
      return '先点一下获取验证码';
    }
    if (this.phone !== VerifyGate.digits(raw)) {
      this.dead();
      return '手机号跟收码的对不上，重新获取一条';
    }
    if (Date.now() - this.sentAt > VerifyGate.TTL_MS) {
      this.dead();
      return '验证码过期了，重新发一条';
    }
    if (this.tries >= VerifyGate.MAX_TRIES) {
      this.dead();
      return '这条验证码作废了，重新获取';
    }
    if (input.trim() !== this.code) {
      this.tries += 1;
      if (this.tries >= VerifyGate.MAX_TRIES) {
        this.dead();
        return '连错三次，这条验证码作废，重新获取';
      }
      return `验证码不对，还能再试 ${VerifyGate.MAX_TRIES - this.tries} 次`;
    }
    this.dead();
    return '';
  }
}
