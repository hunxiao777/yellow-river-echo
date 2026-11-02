# 阿里云短信发送接入

服务端默认使用阿里云号码认证 PNVS 的 SendSmsVerifyCode。SMS_PROVIDER=tencent 才使用旧腾讯云适配。

用户截图确认 Harmony 号码认证方案已配置，三运营商同步成功。该截图未包含短信签名、模板或服务端授权，不能仅凭它调用发送 API；SDK 密钥不是服务端 AccessKeySecret。

1. 在号码认证控制台确认短信认证服务可用，选择服务提供的短信签名和相匹配的模板。当前代码要求模板变量为 code、min。
2. 准备具有 dypns:SendSmsVerifyCode 权限的 RAM 服务端凭据，将其填入 server/.env（从 .env.example 复制）。设置 ALIYUN_ACCESS_KEY_ID、ALIYUN_ACCESS_KEY_SECRET、ALIYUN_SMS_SIGN_NAME、ALIYUN_SMS_TEMPLATE_CODE。不要把 AccessKeySecret 发到聊天或写进 App。
3. ALIYUN_SMS_SCHEME_NAME 是短信认证分组名，不要直接拿截图的 FC 开头 Harmony 方案 Code 替代。服务端生成六位随机码并交由 API 发送，核验仍在现有 AuthCore 中完成，含过期、单次使用和频控；不要把这条流程再接到阿里云 CheckSmsVerifyCode。
4. 设置随机 AUTH_SECRET（至少 32 字符），运行 npm install、npm test、npm start；用真实 HTTPS 域名部署，保持服务运行。
5. 将部署后的 HTTPS 地址填到 entry/src/main/ets/service/AuthService.ets 的 AUTH_BASE_URL，重新编译安装，才会解除当前客户端“登录服务尚未开通”的提示。不能用虚构域名填充。
6. 对本人手机进行一次实际收码和登录验收。现有测试为注入假 API 的单元测试，不发送短信，也不证明云端鉴权、额度或送达成功。

官方依据：https://help.aliyun.com/en/pnvs/developer-reference/api-dypnsapi-2017-05-25-sendsmsverifycode

当前阻塞：没有提供服务端配置位置或部署地址；未执行真实短信请求。截图方案和本机 SDK 凭据已保留，不需要重新申请同一个 Harmony 方案。
