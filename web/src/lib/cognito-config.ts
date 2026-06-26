// Public, client-safe Cognito configuration for the recruiter portal.
// These are not secrets - same as any SPA's Auth0/Firebase config block.
//
// Values below are placeholders until `terraform apply` creates the real
// Cognito resources. After applying, copy the matching `terraform output`
// values in here:
//   terraform output cognito_user_pool_id
//   terraform output cognito_app_client_id
//   terraform output cognito_hosted_ui_domain

export const COGNITO_REGION = "us-east-1";
export const COGNITO_USER_POOL_ID = "us-east-1_TWMEuKgW5";
export const COGNITO_CLIENT_ID = "7q9ommophg8lj4kkc6r3oqorj0";
export const COGNITO_HOSTED_UI_DOMAIN = "mattwindham-auth.auth.us-east-1.amazoncognito.com";

export const COGNITO_IDP_ENDPOINT = `https://cognito-idp.${COGNITO_REGION}.amazonaws.com/`;
export const COGNITO_CALLBACK_URL = "https://mattwindham.dev/portal/callback";
export const COGNITO_LOGOUT_URL = "https://mattwindham.dev/portal/login";
