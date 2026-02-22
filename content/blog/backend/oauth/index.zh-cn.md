---
title: 全栈认证授权解决方案
tags: [后端]
weight: -3
---

认证和授权对于SaaS来说，开发环境懒得搞、费时间，生产环境不搞就不能上线。因此本文将一次性讲清楚性价比最高的解决方案。

## 核心概念

### 认证（Authentication）

判断用户的身份

### 授权（Authorization）

根据用户的身份判断是否要赋予权限

### OAuth2

一种授权协议

### OIDC（OpenID Connect）

基于 OAuth 2.0 构建的认证协议，相当于OAuth 2.0 + 身份认证层

### 基于角色的访问控制（RBAC，Role-Based Access Control）

根据用户的身份赋予权限（例如管理员可以访问`/api/admin/*`，用户可以访问`/api/xxx/*`）

## 传统方案痛点

> 例如账号密码、手搓JWT、session管理……

- 接入第三方登录困难
- 需要编写大量boilerplate代码
- 需要设计数据表、提供CRUD API
- 不安全

## 解决方案

### 原理

这套方案中，一共有三个角色：前端、后端、认证服务器。

流程：

1. 用户点击登录，前端重定向至认证服务器（`/login/authorize?...` ）
2. 登录后，认证服务器重定向至前端（`/callback?code=…` ）
3. 前端将**授权码**发送给后端（为了换取AccessToken）
4. 后端使用前端提供的**授权码**和认证服务器提供的**密钥**，向认证服务器换取**Access Token**
5. 后端将Access Token返回至前端。后端可以选择设置HttpOnly Cookie（更安全）或让前端保存在localStorage）
6. 前端使用AccessToken访问后端受保护的API，后端用私钥校验AccessToken后向认证服务器获取用户的角色信息，再使用RBAC模型进行授权

### 优势

认证服务器全权负责账号密码认证、接入第三方登录、编辑用户信息、2FA等等，无需编写任何样板代码。并且OAuth也是行业的权威标准，安全性有保障。并且一个认证服务器可以管理多个应用的认证授权功能，一劳永逸。

> [!NOTE]
> 我的方案没有使用任何认证授权库，全都是基于HTTP和OIDC协议进行，迁移到别的语言非常方便。后端只要支持中间件/拦截器即可。即使使用Java+SpringBoot, 加起来也不超过200行代码

![image.webp](image.webp)

成品图

- 普通用户（可以编辑自己的用户信息）

![image.webp](image1.webp)

- 管理员（可以管理用户信息、令牌、注册用户等大量功能）
  ![image.webp](image2.webp)
- 权限管理
  ![image.webp](image3.webp)

### 具体操作

#### 搭建认证服务器

1. 用Docker部署认证服务（只要是符合OAuth2和OIDC标准的都可以，比如Keycloak等等），这里选择Casdoor，易用性最佳。（[https://casdoor.org/zh/docs/](https://casdoor.org/zh/docs/)）
   - `docker-compose.yml`

     ```yaml
     services:
       casdoor:
         image: casbin/casdoor:latest
         container_name: casdoor

         volumes:
           - ./conf:/conf

         network_mode: host
     ```

   - `conf/app.conf` （主要配置driverName、dataSourceName、dbName，这里使用PostgreSQL，其他数据库请参考[https://casdoor.org/zh/docs/basic/server-installation#配置数据库](https://casdoor.org/zh/docs/basic/server-installation#%E9%85%8D%E7%BD%AE%E6%95%B0%E6%8D%AE%E5%BA%93)）

   ```yaml
   appname = casdoor
   httpport = 8000
   runmode = prod
   copyrequestbody = true
   driverName = postgres
   dataSourceName = user=casdoor password=123456 host=localhost port=5432 sslmode=disable dbname=casdoor
   dbName = casdoor
   tableNamePrefix =
   showSql = false
   redisEndpoint =
   defaultStorageProvider =
   isCloudIntranet = false
   authState = "casdoor"
   socks5Proxy = "127.0.0.1:10808"
   verificationCodeTimeout = 10
   initScore = 0
   logPostOnly = true
   isUsernameLowered = false
   origin =
   originFrontend =
   staticBaseUrl = "https://cdn.casbin.org"
   isDemoMode = false
   batchSize = 100
   enableErrorMask = false
   enableGzip = true
   inactiveTimeoutMinutes =
   ldapServerPort = 389
   ldapsCertId = ""
   ldapsServerPort = 636
   radiusServerPort = 1812
   radiusDefaultOrganization = "built-in"
   radiusSecret = "secret"
   quota = {"organization": -1, "user": -1, "application": -1, "provider": -1}
   logConfig = {"adapter":"file", "filename": "logs/casdoor.log", "maxdays":99999, "perm":"0770"}
   initDataNewOnly = false
   initDataFile = "./init_data.json"
   frontendBaseDir = "../cc_0"
   ```

2. 访问 `localhost:8000` ，用账号`admin`、密码`123`登录
3. 创建组织（可选），并记住组织的名称（ID）（具体配置略，按照自己需求配置）

   ![image.webp](image4.webp)

4. 在该组织下创建用户（配置略）

   ![image.webp](image5.webp)

   ![image.webp](image6.webp)

5. 创建应用

   ![image.webp](image7.webp)

   为应用填写一个名称（请记录）

   ![image.webp](image8.webp)

   选择刚才创建的组织

   ![image.webp](image9.webp)

   填写2️⃣中的（前端）重定向URL（参照前面的流程），并记录ID和密钥。3️⃣选择JWT-Custom，4️⃣选择Owner和Name（用于后续权限认证）。

   ![image.webp](image10.webp)

   由于我们让Casdoor全权负责用户信息，因此建议启用这个选项，这样登录应用的同时也会登录casdoor。剩余配置请自行探索。

   ![image.webp](image11.webp)

6. 添加角色（一般admin和user就够用了），并为角色添加用户。角色之间也可以互相包含，比如会员当中也包含了管理员，就可以设置vip包含admin角色

   ![image.webp](image12.webp)

   ![image.webp](image13.webp)

7. 设置casbin模型，直接照抄即可

   ![image.webp](image14.webp)

   ![image.webp](image15.webp)

   ```
   [request_definition]
   r = sub, obj, act

   [policy_definition]
   p = sub, obj, act

   [role_definition]
   g = _, _

   [policy_effect]
   e = some(where (p.eft == allow))

   [matchers]
   m = g(r.sub, p.sub) && keyMatch5(r.obj, p.obj) && keyMatch(r.act, p.act)
   ```

8. 按需求添加权限

   ![image.webp](image16.webp)

   按照图片的例子进行配置（资源、动作可以使用通配符`*` ；资源也可以使用path param的通配符，比如`/api/user/{id}`，可以参考[https://www.casbin.org/docs/function](https://www.casbin.org/docs/function)）

   ![image.webp](image17.webp)

9. 下载JWT公钥用于JWT校验

   ![image.webp](image18.webp)

   ![image.webp](image19.webp)

#### 配置后端

> ![NOTE]
> 以Go + fiber为例

1. 配置环境变量

   ```
   ORG_NAME="AuctionMonitorSystemOrganization"
   OIDC_TOKEN_ENDPOINT="http://localhost:8000/api/login/access_token"
   CLIENT_ID="212fad95c629e01d409a"
   CLIENT_SECRET="447024964720a20f6cb8b96abb1246ba8514e03b"

   CASDOOR_ENFORCE_URL="http://localhost:8000/api/enforce"
   FRONTEND_URL="http://localhost:5173" # 用于CORS配置
   ```

2. 配置中间件。注意事项：
   - 中间件负责从Cookie中提取Access Token、解析/校验JWT、调用Casdoor API进行授权（判断用户是否有权限）。如果你没有使用Casdoor，建议获取role之后手动用Casbin进行判断（难度不大，略）
   - 公开的API无法用casdoor实现，需要在中间件里手动配置
   - 解析JWT除了获取信息之外，还有校验其是否被修改的作用，保证安全。需要用到前面下载的公钥
   - JWT的Claims中的Owner、Name（前面配置的）要用于授权。主体（subject）是`Owner/Name`，对象（object）是路由，行为（action）是HTTP方法。

   ```
   package auth

   import (
       "crypto/rsa"
       _ "embed"
       "fmt"
       "strings"

       "github.com/gofiber/fiber/v3"
       "github.com/golang-jwt/jwt/v5"
   )

   const AccessTokenCookie = "access_token"

   func Middleware() fiber.Handler {
       return func(c fiber.Ctx) error {
           if strings.HasPrefix(c.Path(), "/api/auth") {
               return c.Next()
           }

           claims, err := parseJwt(c.Cookies(AccessTokenCookie))
           if err != nil {
               return fiber.NewErrorf(fiber.StatusUnauthorized, "JWT解析失败：%s", err)
           }
           if claims == nil {
               return fiber.ErrUnauthorized
           }

           res, err := Enforce(c.Context(), fmt.Sprintf("%s/%s", claims.Owner, claims.Name), c.Path(), c.Method())
           if err != nil {
               return fiber.NewErrorf(fiber.StatusUnauthorized, "执行enforce失败：%s", err.Error())
           }
           if !res {
               return fiber.ErrUnauthorized
           }

           return c.Next()
       }
   }

   //go:embed token_jwt_key.pem
   var publicKeyString []byte
   var publicKey = func() *rsa.PublicKey {
       result, err := jwt.ParseRSAPublicKeyFromPEM(publicKeyString)
       if err != nil {
           panic(err)
       }
       return result
   }()

   type customClaims struct {
       Owner string `json:"owner"`
       Name  string `json:"name"`
       jwt.RegisteredClaims
   }

   func parseJwt(token string) (*customClaims, error) {
       if len(token) == 0 {
           return nil, nil
       }

       jwtToken, err := jwt.ParseWithClaims(token, &customClaims{}, func(_ *jwt.Token) (any, error) {
           return publicKey, nil
       })
       if err != nil {
           return nil, err
       }
       if claims, ok := jwtToken.Claims.(*customClaims); ok && jwtToken.Valid {
           return claims, nil
       }

       return nil, fiber.ErrUnauthorized
   }

   ```

3. 编写调用Casdoor API的代码。其中一个是调用`/api/login/access_token` ，用授权码换取AccessToken；另一个是根据sub、obj、act判断权限。具体API细节请参考[https://demo.casdoor.com/swagger/](https://demo.casdoor.com/swagger/)和[https://casdoor.org/zh/docs/permission/exposed-casbin-apis](https://casdoor.org/zh/docs/permission/exposed-casbin-apis)

   ```
   package auth

   import (
       "context"
       "errors"

       "auction-monitor-system/util"
       "github.com/gofiber/fiber/v3"
       "github.com/gofiber/fiber/v3/client"
   )

   type Token struct {
       AccessToken  string `json:"access_token"`
       ExpiresIn    int    `json:"expires_in"`
       IdToken      string `json:"id_token"`
       RefreshToken string `json:"refresh_token"`
       Scope        string `json:"scope"`
       TokenType    string `json:"token_type"`
   }

   type tokenRequest struct {
       GrantType    string `json:"grant_type"`
       ClientId     string `json:"client_id"`
       ClientSecret string `json:"client_secret"`
       Code         string `json:"code"`
   }

   var tokenEndpoint = util.GetEnv("OIDC_TOKEN_ENDPOINT")
   var clientId = util.GetEnv("CLIENT_ID")
   var clientSecret = util.GetEnv("CLIENT_SECRET")

   func GetToken(ctx context.Context, code string) (*Token, error) {
       logger := util.LoggerFromCtx(ctx, util.RequestIdKey)
       logger.Info().Str("code", code).Msg("开始获取Token")

       resp, err := util.HttpClient.Post(tokenEndpoint, client.Config{
           Ctx: ctx,
           Body: tokenRequest{
               GrantType:    "authorization_code",
               ClientId:     clientId,
               ClientSecret: clientSecret,
               Code:         code,
           },
       })
       if err != nil {
           logger.Error().Err(err).Msg("HTTP请求失败")
           return nil, err
       }
       if err = util.CheckResp(resp); err != nil {
           logger.Error().Err(err).Msg("HTTP请求错误")
           return nil, err
       }

       var token Token
       if err = resp.JSON(&token); err != nil {
           logger.Error().Err(err).Msg("JSON解析失败")
           return nil, err
       }

       logger.Info().Msg("Token获取成功")
       return &token, nil
   }

   var orgName = util.GetEnv("ORG_NAME")
   var casdoorEnforceUrl = util.GetEnv("CASDOOR_ENFORCE_URL")

   func Enforce(ctx context.Context, sub, obj, act string) (bool, error) {
       logger := util.LoggerFromCtx(ctx, util.RequestIdKey)

       resp, err := util.HttpClient.Post("http://localhost:8000/api/enforce", client.Config{
           Ctx: ctx,
           Param: map[string]string{
               "owner": orgName,
           },
           Header: map[string]string{
               fiber.HeaderAuthorization: util.BasicAuth(clientId, clientSecret),
           },
           Body: []string{sub, obj, act},
       })
       if err != nil {
           logger.Error().Err(err).Msg("HTTP请求失败")
           return false, err
       }
       if err = util.CheckResp(resp); err != nil {
           logger.Error().Err(err).Msg("HTTP请求错误")
           return false, err
       }

       var result struct {
           Data []bool `json:"data"`
           Msg  string `json:"msg"`
       }
       if err := resp.JSON(&result); err != nil {
           logger.Error().Err(err).Msg("JSON解析失败")
           return false, err
       }
       if result.Data == nil {
           return false, errors.New(result.Msg)
       }

       return result.Data[0], nil
   }

   ```

4. 暴露后端API给前端。注意我们要使用HttpOnly Cookie，相比localStorage更安全。

   ```
   authGroup := router.Group("/auth")
   authGroup.Post("/exchange", h.ExchangeAccessToken)
   authGroup.Post("/logout", h.Logout)
   ```

   ```
   package api

   import (
       "fmt"

       "auction-monitor-system/auth"
       "auction-monitor-system/util"
       "github.com/gofiber/fiber/v3"
   )

   func (h *Handler) ExchangeAccessToken(c fiber.Ctx) error {
       logger := util.LoggerFromCtx(c.Context(), util.RequestIdKey)
       logger.Info().Msg("开始交换Token")

       var body struct {
           Code string `json:"code"`
       }
       if err := c.Bind().JSON(&body); err != nil {
           logger.Error().Err(err).Msg("JSON解析失败")
           return fiber.NewErrorf(fiber.StatusBadRequest, "JSON解析失败：%s", err)
       }

       resp, err := auth.GetToken(c.Context(), body.Code)
       if err != nil {
           logger.Error().Err(err).Msg("Token获取失败")
           return fmt.Errorf("token获取失败：%w", err)
       }

       logger.Info().Msg("Token交换成功")
       c.Cookie(&fiber.Cookie{
           Name:     auth.AccessTokenCookie,
           Value:    resp.AccessToken,
           HTTPOnly: true,
           SameSite: fiber.CookieSameSiteStrictMode,
           Path:     "/api",
           MaxAge:   resp.ExpiresIn,
       })
       return c.JSON(empty)
   }

   func (h *Handler) Logout(c fiber.Ctx) error {
       c.Cookie(&fiber.Cookie{
           Name:   auth.AccessTokenCookie,
           Value:  "",
           Path:   "/api",
           MaxAge: -1,
       })
       return c.JSON(empty)
   }

   ```

5. 配置CORS

   ```
   app.Use(cors.New(cors.Config{
           AllowCredentials: true,
           AllowOrigins:     []string{util.GetEnv("FRONTEND_URL")},
   }))
   ```

#### 配置前端

> [!NOTE]
> 以Preact、Vite、TanStack Query为例

1. 配置环境变量(`.env.development`，开发环境自行修改）

   ```
   VITE_AUTHORIZATION_ENDPOINT="<casdoor地址>/login/authorize" # 登录地址
   VITE_CLIENT_ID="212fad95c629e01d409a" # 客户端ID
   VITE_APP_NAME="AuctionMonitorSystem" # 应用名
   VITE_APP_URL="http://localhost:5173" # 前端URL
   VITE_CALLBACK_ROUTE="/callback" # 回调的路由
   VITE_BACKEND_URL="http://localhost:3000" # 后端URL
   ```

2. 创建登录URL（用`<a>` 链接引导用户跳转即可，登录页面同时可以进行注册）

   ```tsx
   export const loginUrl =
     import.meta.env.VITE_AUTHORIZATION_ENDPOINT +
     "?" +
     new URLSearchParams({
       client_id: import.meta.env.VITE_CLIENT_ID,
       redirect_uri: import.meta.env.VITE_APP_URL + "/callback",
       response_type: "code",
       scope: "openid",
       state: import.meta.env.VITE_APP_NAME,
     }).toString();
   ```

3. 配置回调页面（由于是Cookie携带Token，因此请求成功后不需要处理响应体）

   ```tsx
   import { api } from "../util/api.ts";
   import { useMutation } from "@tanstack/react-query";
   import { useLocation } from "preact-iso";
   import { useEffect, useMemo } from "preact/hooks";

   export default function CallbackPage() {
     const location = useLocation();
     const code = useMemo(() => location.query["code"], [location]);

     const { mutate, isError, error } = useMutation({
       mutationFn: (code: string) => api.apiAuthExchangePost({ code: { code } }),
       onSuccess: () => location.route("/", true), // 获取Token成功后跳转到首页
     });

     useEffect(() => {
       if (code) mutate(code);
     }, [code]);

     if (!code) return <p>错误：无授权码</p>;
     if (isError) return <p>错误：{error.message}</p>;

     return <p>等待认证成功……</p>;
   }
   ```

4. 配置`fetch`：由于使用了HttpOnly Cookie，因此不需要手动设置Token，请求时自动携带Token，但是需要添加`credentials: "include"` 选项。
5. 登出只需要调用后端API清除Cookie、调用`casdoor地址**/api/logout**`即可。
6. 如果用户需要修改个人信息，引导他们跳转到`<casdoor地址>/account`即可。如果前端需要展示用户信息需要和后端协作

> 题外话：虽然OpenAPI写起来稍微有些麻烦，但是它不仅可以一键生成文档、调试API，还能一键生成前端的HttpClient的样板代码，再搭配TanStack Query开发效率非常高

## Casdoor优势

1. 极其大量的第三方登录支持（实际上只要支持了OAuth协议，大差不差）

   ![image.webp](image20.webp)

2. SaaS便捷功能（邀请码、校验码、支付等）

![image.webp](image21.webp)

![image.webp](image22.webp)

![image.webp](image23.webp)

1. 可观测性（日志、审计、系统信息监控）
2. golang编写，性能优越

## 另一种授权方案

由于用户注册（包括邀请码注册）时，casdoor无法自动授予角色（理论上通过API也可以，但比较麻烦），因此这里介绍用群组授权的方式。

假设你已经完成了上述的步骤：

1. 修改JWT携带的信息。由于我们要用群组认证，所以要携带Groups信息

   ![image.webp](image24.webp)

2. 自行添加几个群组，并修改用户的群组。这里以admin_group和vip_group群组为例

   ![image.webp](image25.webp)

   ![image.webp](image26.webp)

3. casbin模型不用变，但是我们要创建一个casbin适配器，用来填写授权的policy

   ![image.webp](image27.webp)

   必须点击“Test DB Connection”，casbin才会创建数据表

   ![image.webp](image28.webp)

4. 添加casbin执行器

   ![image.webp](image29.webp)

   选好模型和适配器后，先点一下保存，然后点同步

   ![image.webp](image30.webp)

5. 往casbin执行器中添加策略。策略类型分为p（enforce的策略）和g（role的定义）。`g x y` 的意思是x继承y的所有权限，比如admin继承vip权限。具体请参考[https://www.casbin.org/docs/rbac](https://www.casbin.org/docs/rbac)

   ![image.webp](image31.webp)

6. 修改后端代码中jwt claims的定义（现在我们要从JWT中获取group信息）

   ```
   type customClaims struct {
       Groups []string `json:"groups"`
       jwt.RegisteredClaims
   }
   ```

7. 修改中间件代码，将subject改为group。由于我们用的是自定义策略，因此/api/auth这种公开API也可以用casdoor授权了。（注意我在代码中将没有claims的角色设定为none，有claims但是没有group的角色设置为default）

   ```
   func Middleware() fiber.Handler {
       return func(c fiber.Ctx) error {
           claims, err := parseJwt(c.Cookies(AccessTokenCookie))
           if err != nil {
               return fiber.NewErrorf(fiber.StatusUnauthorized, "JWT解析失败：%s", err)
           }

           var sub string
           switch {
           case claims == nil:
               sub = "none"
           case len(claims.Groups) == 0:
               sub = "default"
           default:
               sub = claims.Groups[0]
           }

           res, err := Enforce(c.Context(), sub, c.Path(), c.Method())
           if err != nil {
               return fiber.NewErrorf(fiber.StatusUnauthorized, "执行enforce失败：%s", err.Error())
           }
           if !res {
               return fiber.ErrUnauthorized
           }

           return c.Next()
       }
   }
   ```

8. 修改环境变量和调用Enforce API的代码

   ```
   ENFORCER_ID="AuctionMonitorSystemOrganization/enforcer_ams"
   ```

   ```
   var enforcerId = util.GetEnv("ENFORCER_ID") // 从环境变量读取ID

   func Enforce(ctx context.Context, sub, obj, act string) (bool, error) {
       logger := util.LoggerFromCtx(ctx, util.RequestIdKey)

       resp, err := util.HttpClient.Post(enforceUrl, client.Config{
           Ctx: ctx,
           Param: map[string]string{
               "enforcerId": enforcerId, // 只需修改这里
           },
           Header: map[string]string{
               fiber.HeaderAuthorization: util.BasicAuth(clientId, clientSecret),
           },
           Body: []string{sub, obj, act},
       })

   // 后续代码略
   ```

## 前端展示用户信息

由于我们让casdoor全权接管了用户管理，因此我们需要一些手段才能在前端展示用户信息。

我们可以使用标准的OIDC API（/api/userinfo）实时获取用户信息（由于JWT无法在用户信息改变时自动更新，因此从JWT获取用户信息不合适），用Bearer Token访问该API即可。返回结果类似于：

```json
{
  "sub": "7808235c-4f97-4b41-b881-f70a26f83ae1",
  "iss": "http://localhost:8000",
  "aud": "212fad95c629e01d409a",
  "preferred_username": "mioyi", // 用户名
  "name": "澪依12", // 昵称
  "picture": "https://cdn.casbin.org/img/casbin.svg", // 头像
  "groups": ["AuctionMonitorSystemOrganization/admin_group"]
}
```

如果你没有使用HttpOnly Cookie，可以前端向casdoor服务器直接发起请求，否则需要经过后端周转才行。

前端跳转登录时，scope需要设置为openid和profile才能获取用户信息。

```tsx
export const LOGIN_URL =
  import.meta.env.VITE_AUTHORIZATION_ENDPOINT +
  "?" +
  new URLSearchParams({
    client_id: import.meta.env.VITE_CLIENT_ID,
    redirect_uri: import.meta.env.VITE_APP_URL + "/callback",
    response_type: "code",
    scope: "openid profile",
    state: import.meta.env.VITE_APP_NAME,
  }).toString();
```
