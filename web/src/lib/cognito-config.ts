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
export const COGNITO_USER_POOL_ID = "REPLACE_WITH_terraform_output_cognito_user_pool_id";
export const COGNITO_CLIENT_ID = "REPLACE_WITH_terraform_output_cognito_app_client_id";
export const COGNITO_HOSTED_UI_DOMAIN = "REPLACE_WITH_terraform_output_cognito_hosted_ui_domain";

export const COGNITO_IDP_ENDPOINT = `https://cognito-idp.${COGNITO_REGION}.amazonaws.com/`;
export const COGNITO_CALLBACK_URL = "https://mattwindham.dev/portal/callback";
export const COGNITO_LOGOUT_URL = "https://mattwindham.dev/portal/login";
