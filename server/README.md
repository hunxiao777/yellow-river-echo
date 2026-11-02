# 黄河续响登录接入

当前已实现手机号验证码界面、腾讯云真实短信适配、验证码校验、会话签发、微信/QQ 网站 OAuth 的服务端交换及一次性轮询。**未开通任何短信或开放平台服务，当前不能真实发送短信或完成第三方登录。** 没有默认验证码、模拟登录成功或把离线体验当作认证。

## 短信开通与运行

1. 开通腾讯云短信，完成主体认证，创建短信应用。申请审核通过的签名及验证码模板；模板应含两个参数：验证码、有效分钟数。例如“验证码为 {1}，{2} 分钟内有效”。购买所需短信额度。
2. 创建仅用于发送短信的服务端凭据。复制 `.env.example` 为 `.env`，填入 SecretId、SecretKey、SmsSdkAppId、签名和模板 ID；不要提交 `.env`，也不要把密钥放入 ArkTS。
3. 使用 Node.js 22.13+（推荐当前 Node 24），在本目录运行 `npm install`。用密码管理器生成至少 32 字符的随机 `AUTH_SECRET`。配置 `PUBLIC_BASE_URL` 为真实 HTTPS 服务域名。
4. `npm start` 启动服务，`npm test` 运行不发送真实短信的测试。服务默认仅监听 127.0.0.1:8787，需要 HTTPS 反向代理。数据库保存在 `DATABASE` 指定路径，备份并限制文件访问权限。
5. 在 `entry/src/main/ets/service/AuthService.ets` 设置 `AUTH_BASE_URL` 为上述 HTTPS 域名（不带末尾斜杠），重新构建安装。模拟器必须可访问该地址，模拟器的 localhost 并不等于电脑的 localhost。
6. 使用本人的手机完成发送、输入验证码、登录和过期重试验收。前端仅在服务端确认发送成功后开始倒计时；仅在服务端返回 token 后进入线上登录状态。

依据：[腾讯云 2021-01-11 SendSms API](https://cloud.tencent.com/document/api/382/55981)、[Node.js SDK](https://cloud.tencent.com/document/product/382/56060)。

## 微信、QQ：明确接入类型

本次实现的是 **系统浏览器中的网站 OAuth 授权**，不是已经接好的“原生微信/QQ 客户端一键拉起”。微信网站流程为扫码授权，同一台手机上的体验和原生移动 SDK 不同。

- 网站流程需要分别申请审核通过的网站应用及登录权限，配置回调域名。服务端填入对应网站应用的 ID 与 secret；不要混用移动应用的 AppID。
- 微信回调：`https://你的域名/auth/oauth/callback/wechat`；QQ 回调：`https://你的域名/auth/oauth/callback/qq`。
- 应用向 `/auth/oauth/start` 获取短时授权 ticket，打开系统浏览器官方授权地址，返回后轮询 `/auth/oauth/poll`。平台 code 只在后端交换，state 和 ticket 一次性使用，用户取消或授权超时不会登录成功。
- QQ 官方说明不支持 App 内嵌 H5 登录，因此这里不嵌入授权 WebView。参见 [QQ Authorization Code 文档](https://wiki.connect.qq.com/使用authorization_code获取access_token)。微信参见 [网站应用登录文档](https://developers.weixin.qq.com/doc/oplatform/Website_App/WeChat_Login/Wechat_Login.html)。
- 如果目标是原生手机 App 的微信/QQ 一键登录：下一阶段需要申请**移动应用**、绑定实际包名和签名、取得适用当前 HarmonyOS 版本的官方 SDK，按官方 SDK 加入回调 Ability 并进行真机验收。不能用网站配置冒充完成这一步；当前仓库未包含或验证原生 SDK。

## API

| 方法与路径 | 请求 | 返回 |
| --- | --- | --- |
| POST /auth/sms/send | phone | retryAfter、message（不返回验证码） |
| POST /auth/sms/verify | phone、code | token、nick |
| GET /auth/me | Authorization: Bearer token | nick；失效返回 401 |
| POST /auth/oauth/start | provider: wechat / qq | ticket、authorizationUrl |
| POST /auth/oauth/poll | ticket | pending，或一次性 token |

验证码 5 分钟有效，60 秒发送间隔，单手机号每日限额、IP 限流、最多 5 次错误；数据库保存验证码 HMAC 和 token 哈希。客户端 token 只在内存保存，重新启动需重新登录；离线入口明确独立。

## 上线前仍需完成

这是单实例可联调服务。应补充正式隐私政策/用户协议、运营方信息、短信风控/验证码挑战、边缘 IP 限流、监控和额度告警。反向代理需自己限流，本代码不信任客户端伪造的 X-Forwarded-For；多个实例需共享事务存储/限流。现有收藏与名片仍是设备本地数据，尚未提供跨账号云端同步和账号数据隔离；不得据此宣称已完成生产账号体系。
