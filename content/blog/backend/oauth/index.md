---
title: Full-Stack Authentication and Authorization Solution
tags: [backend]
----------

For SaaS development, authentication and authorization are often too tedious to build from scratch in development environments, yet essential for production. This article explains the most cost-effective solution in one go.

## Core Concepts

### Authentication
Determining the identity of a user.

### Authorization
Determining whether to grant permissions based on the user's identity.

### OAuth2
An authorization protocol.

### OIDC (OpenID Connect)
An authentication protocol built on top of OAuth 2.0, effectively OAuth 2.0 + an identity layer.

### Role-Based Access Control (RBAC)
Granting permissions based on user roles (e.g., an admin can access `/api/admin/*`, while a user can access `/api/xxx/*`).

## Pain Points of Traditional Solutions

> e.g., Username/Password, hand-rolled JWT, session management...

- Difficult to integrate third-party logins.
- Requires writing large amounts of boilerplate code.
- Requires designing data tables and providing CRUD APIs.
- Insecure.

## The Solution

### Principle

In this solution, there are three roles: Frontend, Backend, and Authentication Server.

Workflow:

1. User clicks login; the frontend redirects to the Authentication Server (`/login/authorize?...`).
2. After logging in, the Authentication Server redirects back to the frontend (`/callback?code=…`).
3. The frontend sends the **Authorization Code** to the backend (to exchange for an AccessToken).
4. The backend uses the **Authorization Code** provided by the frontend and the **Client Secret** provided by the Authentication Server to exchange for an **Access Token** from the server.
5. The backend returns the Access Token to the frontend. The backend can choose to set an HttpOnly Cookie (more secure) or let the frontend store it in `localStorage`.
6. The frontend uses the AccessToken to access protected APIs. The backend verifies the AccessToken using a public key, retrieves user role information, and performs authorization using the RBAC model.

### Advantages

The Authentication Server handles everything: username/password auth, third-party logins, user profile editing, 2FA, etc., eliminating boilerplate code. OAuth is an industry standard with guaranteed security. Furthermore, one Authentication Server can manage multiple applications, providing a once-and-for-all solution.

> \[!NOTE]
> My solution does not use any specific auth libraries; it is entirely based on HTTP and OIDC protocols, making migration to other languages very easy. The backend only needs to support middleware/interceptors. Even with Java + Spring Boot, the code totals less than 200 lines.

![image.webp](image.webp)

Finished Product Screenshots:

- Regular User (can edit own profile)

![image.webp](image1.webp)

- Admin (can manage users, tokens, registration, and many other features)
  ![image.webp](image2.webp)
- Permission Management
  ![image.webp](image3.webp)

### Implementation

#### Set Up the Authentication Server

1. Deploy the authentication service using Docker. Any server compliant with OAuth2 and OIDC standards works (e.g., Keycloak). Here we choose Casdoor for its superior ease of use. (<https://casdoor.org/docs/>)

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

   - `conf/app.conf` (Mainly configure `driverName`, `dataSourceName`, and `dbName`. Here we use PostgreSQL; for others, see [https://casdoor.org/docs/basic/server-installation#configure-database](https://casdoor.org/docs/basic/server-installation#configure-database))

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

2. Visit `localhost:8000`, log in with username `admin` and password `123`.

3. Create an Organization (optional) and remember the organization name (ID). (Details omitted; configure based on your needs).

   ![image.webp](image4.webp)

4. Create Users under this organization.

   ![image.webp](image5.webp)

   ![image.webp](image6.webp)

5. Create an Application.

   ![image.webp](image7.webp)

   Enter a name for the application (record this).

   ![image.webp](image8.webp)

   Select the organization created earlier.

   ![image.webp](image9.webp)

   Fill in the (frontend) redirect URL (refer to the previous workflow) and record the ID and Secret. In 3️⃣, select `JWT-Custom`; in 4️⃣, select `Owner` and `Name` (used for subsequent permission verification).

   ![image.webp](image10.webp)

   Since we let Casdoor fully manage user information, it is recommended to enable this option so that logging into the app also logs you into Casdoor. Explore other configurations as needed.

   ![image.webp](image11.webp)

6. Add Roles (usually `admin` and `user` are enough) and assign users to roles. Roles can also inherit from each other; for example, if VIPs also have admin rights, you can configure the `vip` role to inherit the `admin` role.

   ![image.webp](image12.webp)

   ![image.webp](image13.webp)

7. Set up the Casbin model—you can copy this directly:

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

8. Add permissions as required.

   ![image.webp](image16.webp)

   Follow the example in the image (Resources and Actions can use wildcard `*`; Resources can also use path param wildcards like `/api/user/{id}`, see <https://www.casbin.org/docs/function>).

   ![image.webp](image17.webp)

9. Download the JWT Public Key for verification.

   ![image.webp](image18.webp)

   ![image.webp](image19.webp)

#### Backend Configuration

> \[!NOTE]
> Example using Go + Fiber.

1. Configure environment variables:

   ```
   ORG_NAME="AuctionMonitorSystemOrganization"
   OIDC_TOKEN_ENDPOINT="http://localhost:8000/api/login/access_token"
   CLIENT_ID="212fad95c629e01d409a"
   CLIENT_SECRET="447024964720a20f6cb8b96abb1246ba8514e03b"

   CASDOOR_ENFORCE_URL="http://localhost:8000/api/enforce"
   FRONTEND_URL="http://localhost:5173" # For CORS configuration
   ```

2. Configure Middleware. Notes:

   - Middleware is responsible for extracting the Access Token from Cookies, parsing/verifying the JWT, and calling the Casdoor API for authorization. If you aren't using Casdoor, perform Casbin checks manually after getting the role.
   - Public APIs cannot be managed by Casdoor and must be configured manually in the middleware.
   - Parsing the JWT verifies its integrity (using the previously downloaded public key).
   - The `Owner` and `Name` in JWT Claims are used for authorization. The subject is `Owner/Name`, the object is the route, and the action is the HTTP method.

   ```go
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
               return fiber.NewErrorf(fiber.StatusUnauthorized, "JWT parsing failed: %s", err)
           }
           if claims == nil {
               return fiber.ErrUnauthorized
           }

           res, err := Enforce(c.Context(), fmt.Sprintf("%s/%s", claims.Owner, claims.Name), c.Path(), c.Method())
           if err != nil {
               return fiber.NewErrorf(fiber.StatusUnauthorized, "Enforce failed: %s", err.Error())
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

3. Write code to call Casdoor APIs. One calls `/api/login/access_token` to exchange the code for an AccessToken; the other calls enforce based on `sub`, `obj`, and `act`. See <https://demo.casdoor.com/swagger/> and <https://casdoor.org/docs/permission/exposed-casbin-apis> for API details.

   ```go
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
       logger.Info().Str("code", code).Msg("Starting Token acquisition")

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
           logger.Error().Err(err).Msg("HTTP request failed")
           return nil, err
       }
       if err = util.CheckResp(resp); err != nil {
           logger.Error().Err(err).Msg("HTTP request error")
           return nil, err
       }

       var token Token
       if err = resp.JSON(&token); err != nil {
           logger.Error().Err(err).Msg("JSON parsing failed")
           return nil, err
       }

       logger.Info().Msg("Token acquired successfully")
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
           logger.Error().Err(err).Msg("HTTP request failed")
           return false, err
       }
       if err = util.CheckResp(resp); err != nil {
           logger.Error().Err(err).Msg("HTTP request error")
           return false, err
       }

       var result struct {
           Data []bool `json:"data"`
           Msg  string `json:"msg"`
       }
       if err := resp.JSON(&result); err != nil {
           logger.Error().Err(err).Msg("JSON parsing failed")
           return false, err
       }
       if result.Data == nil {
           return false, errors.New(result.Msg)
       }

       return result.Data[0], nil
   }
   ```

4. Expose backend APIs to the frontend. Note: We use HttpOnly Cookies for security over `localStorage`.

   ```go
   authGroup := router.Group("/auth")
   authGroup.Post("/exchange", h.ExchangeAccessToken)
   authGroup.Post("/logout", h.Logout)
   ```

   ```go
   package api

   import (
       "fmt"

       "auction-monitor-system/auth"
       "auction-monitor-system/util"
       "github.com/gofiber/fiber/v3"
   )

   func (h *Handler) ExchangeAccessToken(c fiber.Ctx) error {
       logger := util.LoggerFromCtx(c.Context(), util.RequestIdKey)
       logger.Info().Msg("Starting Token exchange")

       var body struct {
           Code string `json:"code"`
       }
       if err := c.Bind().JSON(&body); err != nil {
           logger.Error().Err(err).Msg("JSON parsing failed")
           return fiber.NewErrorf(fiber.StatusBadRequest, "JSON parsing failed: %s", err)
       }

       resp, err := auth.GetToken(c.Context(), body.Code)
       if err != nil {
           logger.Error().Err(err).Msg("Token acquisition failed")
           return fmt.Errorf("token acquisition failed: %w", err)
       }

       logger.Info().Msg("Token exchange successful")
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

5. Configure CORS

   ```go
   app.Use(cors.New(cors.Config{
           AllowCredentials: true,
           AllowOrigins:     []string{util.GetEnv("FRONTEND_URL")},
   }))
   ```

#### Frontend Configuration

> \[!NOTE]
> Example using Preact, Vite, and TanStack Query.

1. Configure environment variables (`.env.development`):

   ```
   VITE_AUTHORIZATION_ENDPOINT="<casdoor-url>/login/authorize" # Login URL
   VITE_CLIENT_ID="212fad95c629e01d409a" # Client ID
   VITE_APP_NAME="AuctionMonitorSystem" # App Name
   VITE_APP_URL="http://localhost:5173" # Frontend URL
   VITE_CALLBACK_ROUTE="/callback" # Callback Route
   VITE_BACKEND_URL="http://localhost:3000" # Backend URL
   ```

2. Create the Login URL (Direct the user via an `<a>` link; the login page also supports registration):

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

3. Configure the Callback Page (Since the Token is in a Cookie, the response body doesn't need manual processing):

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
       onSuccess: () => location.route("/", true), // Redirect to home after success
     });

     useEffect(() => {
       if (code) mutate(code);
     }, [code]);

     if (!code) return <p>Error: No authorization code</p>;
     if (isError) return <p>Error: {error.message}</p>;

     return <p>Waiting for authentication...</p>;
   }
   ```

4. Configure `fetch`: Since we use HttpOnly Cookies, manual Token setting is unnecessary. Tokens are sent automatically, but you must include `credentials: "include"`.

5. To Log out, call the backend API to clear the cookie and, if needed, call `<casdoor-url>/api/logout`.

6. To Edit Personal Info, redirect users to `<casdoor-url>/account`. If the frontend needs to display user info, it necessitates backend coordination.

> Aside: While OpenAPI can be slightly verbose to write, it generates documentation, enables API debugging, and creates frontend HttpClient boilerplate. Combined with TanStack Query, it significantly boosts efficiency.

## Advantages of Casdoor

1. Massive support for third-party logins (practically anything OAuth-compatible).

   ![image.webp](image20.webp)

2. Convenient SaaS features (Invitation codes, verification codes, payments, etc.).

![image.webp](image21.webp)

![image.webp](image22.webp)

![image.webp](image23.webp)

1. Observability (Logs, auditing, system monitoring).
2. Written in Golang for high performance.

## Alternative Authorization Scheme

Since Casdoor cannot automatically grant roles during user registration (it is possible via API, but complex), here is a Group-based authorization method.

Assuming the previous steps are completed:

1. Modify JWT Claims. We need to include Group info for group authentication.

   ![image.webp](image24.webp)

2. Add some groups and assign users to them. Example: `admin_group` and `vip_group`.

   ![image.webp](image25.webp)

   ![image.webp](image26.webp)

3. The Casbin model remains the same, but we create a Casbin Adapter to store the policy.

   ![image.webp](image27.webp)

   You must click "Test DB Connection" for Casbin to create the database tables.

   ![image.webp](image28.webp)

4. Add a Casbin Enforcer.

   ![image.webp](image29.webp)

   Select the model and adapter, click Save, then click Sync.

   ![image.webp](image30.webp)

5. Add policies to the Casbin Enforcer. Policy types are `p` (enforce policy) and `g` (role definition). `g x y` means `x` inherits all permissions of `y`. See <https://www.casbin.org/docs/rbac>.

   ![image.webp](image31.webp)

6. Update the backend JWT claims definition (to get groups from the JWT).

   ```go
   type customClaims struct {
       Groups []string `json:"groups"`
       jwt.RegisteredClaims
   }
   ```

7. Update Middleware to use groups as the subject. Since we use custom policies, public APIs like `/api/auth` can now be authorized via Casdoor. (I set roles with no claims to `none` and roles with claims but no groups to `default`).

   ```go
   func Middleware() fiber.Handler {
       return func(c fiber.Ctx) error {
           claims, err := parseJwt(c.Cookies(AccessTokenCookie))
           if err != nil {
               return fiber.NewErrorf(fiber.StatusUnauthorized, "JWT parsing failed: %s", err)
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
               return fiber.NewErrorf(fiber.StatusUnauthorized, "Enforce failed: %s", err.Error())
           }
           if !res {
               return fiber.ErrUnauthorized
           }

           return c.Next()
       }
   }
   ```

8. Update environment variables and Enforce API code:

   ```
   ENFORCER_ID="AuctionMonitorSystemOrganization/enforcer_ams"
   ```

   ```go
   var enforcerId = util.GetEnv("ENFORCER_ID")

   func Enforce(ctx context.Context, sub, obj, act string) (bool, error) {
       logger := util.LoggerFromCtx(ctx, util.RequestIdKey)

       resp, err := util.HttpClient.Post(enforceUrl, client.Config{
           Ctx: ctx,
           Param: map[string]string{
               "enforcerId": enforcerId, // Changed here
           },
           Header: map[string]string{
               fiber.HeaderAuthorization: util.BasicAuth(clientId, clientSecret),
           },
           Body: []string{sub, obj, act},
       })
   // Remaining code omitted
   ```

## Displaying User Info in the Frontend

Since Casdoor handles user management, we need a way to display info on the frontend.

We can use the standard OIDC API (`/api/userinfo`) to get real-time info (getting info from JWT isn't ideal as it doesn't update when user data changes). Access it using a Bearer Token. Result:

```json
{
  "sub": "7808235c-4f97-4b41-b881-f70a26f83ae1",
  "iss": "http://localhost:8000",
  "aud": "212fad95c629e01d409a",
  "preferred_username": "mioyi", 
  "name": "Mioyi12", 
  "picture": "https://cdn.casbin.org/img/casbin.svg", 
  "groups": ["AuctionMonitorSystemOrganization/admin_group"]
}
```

If not using HttpOnly Cookies, the frontend can call Casdoor directly. Otherwise, the request must go through the backend.

When redirecting to login, set the scope to `openid profile` to retrieve user information.

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