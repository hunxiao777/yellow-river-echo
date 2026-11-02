# 阿里云 Harmony 号码认证接入

已引入用户提供的 `auth_number_product-v2.0.25-log-online-standard-release.har`，保存为 `entry/libs/numberauth-2.0.25.har`，依赖名称为 `numberauth_standard`。登录页新增本机号码授权入口，路由为 `pages/NumberAuthPage`。

本 SDK 示例提供一键登录和本机号码验证，不是短信验证码发送 SDK。现有短信入口保留。

当前集成范围：本地依赖、SDK 初始化、授权页配色、获取 token、失败提示与退出清理。**服务端 token 换手机号及业务会话签发尚未接入，不能完成真实账号登录。** SDK 回调 token 不记录、不保存、不当作业务登录凭据。

启用前需要：

1. 在阿里云号码认证控制台为实际 Harmony 应用配置包名、签名等信息，并取得对应 SDK 凭据。
2. 将 `entry/src/main/ets/service/NumberAuthConfig.example.ets` 复制为同目录的 `NumberAuthConfig.local.ets`，填写 `NUMBER_AUTH_SDK_INFO`。本机已配置用户提供的 SDK 凭据，本地配置被 Git 忽略；其他机器需自行配置。它不是阿里云 AccessKeySecret，云服务私钥禁止放入客户端。
3. 在后端实现官方 token 核验／换号接口；核验通过后再签发本应用 token，并连接现有 AuthService 登录链路。
4. 配置正式服务协议，保留运营商授权确认；在有 SIM 卡与运营商网络的受支持真机上验收成功、取消、失败与重试。模拟器及编译通过不代表运营商认证通过。

在这些配置完成前，入口明确提示缺少配置，不模拟认证成功。
