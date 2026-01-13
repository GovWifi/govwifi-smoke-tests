# GovWifi Smoke Tests

This is a collection of rspec with Capybara tests, using Firefox to access the live application.

## Running the tests

The tests run in a headless browser inside a Docker container. You need to provide some environment variables:

- `GW_USER` - the email address that can sign in to the admin
- `GW_PASS` - the associated password
- `GW_2FA_SECRET` - the secret contained in the QR code when setting up 2FA
- `GW_SUPER_ADMIN_USER` - the email address of a super user that can sign in to the admin. This is needed to remove end users before running the tests.
- `GW_SUPER_ADMIN_PASS` - the associated password
- `GW_SUPER_ADMIN_2FA_SECRET` - the associated 2FA secret
- `SUBDOMAIN` - the subdomain for your particular environment e.g. `wifi` or `staging.wifi`
- `GOOGLE_API_CREDENTIALS` - token for the Google API.
- `GOOGLE_API_TOKEN_DATA` - token for the Google API.
- `NOTIFY_FIELD` - the notify email prefix, for the given environment, govwifi(development, staging, blank)
- `RADIUS_KEY` - Key to allow access to radius, this is located in the admin app > org > locations
- `RADIUS_IPS` - allow list for radius, again located in the admin app > org > locations
- `NOTIFY_SMOKETEST_API_KEY` - api key for notify, see Notify App.
- `NOTIFY_GO_TEMPLATE_ID` - Template ID for template, see Notify App.
- `GOVWIFI_PHONE_NUMBER` -  Phone number for the gov wifi virtual phone
- `SMOKETEST_PHONE_NUMBER` - gPhone number for the smoke test user virtual phone

An example of setting the environment variables
```
export GW_USER=email@address.tld
export GW_PASS=Y0uR_PA55W0rD
export GW_2FA_SECRET=1234567890ABCDEF
export GW_SUPER_ADMIN_USER=superuser@address.tld
export GW_SUPER_ADMIN_PASS=paswd
export GW_SUPER_ADMIN_2FA_SECRET=123
export SUBDOMAIN=wifi
export GOOGLE_API_CREDENTIALS='{"access_token....}'
export GOOGLE_API_TOKEN_DATA='{"web":{....}}'
export NOTIFY_FIELD=govwifidevelopment
export RADIUS_KEY=abcdefghijklmnopqrstuvwxyz1234567890
export RADIUS_IPS=1.2.3.4
export NOTIFY_SMOKETEST_API_KEY=123456abcdefg
export NOTIFY_GO_TEMPLATE_ID=lakdfjlsdkj323423423
export GOVWIFI_PHONE_NUMBER=01202123456
export SMOKETEST_PHONE_NUMBER=01202123456
```

When running the smoke tests, ensure that both the super user and the regular admin user that were defined in the environment variables exist in the admin app.
Furthermore, ensure that the regular admin user is a member of two organisations, where one of the organisations should be called "Automated Test 2"

You can find the values of the environment variables in AWS secrets manager:
- `GW_USER` - deploy/gw_user
- `GW_PASS` - deploy/gw_pass
- `GW_2FA_SECRET` - deploy/gw_2fa_secret
- `GW_SUPER_ADMIN_USER` - deploy/gw_super_admin_user
- `GW_SUPER_ADMIN_PASS` - deploy/gw_super_admin_pass
- `GW_SUPER_ADMIN_2FA_SECRET` - deploy/gw_super_admin_2fa_secret
- `GOOGLE_API_CREDENTIALS` - deploy/google_api_credentials
- `GOOGLE_API_TOKEN_DATA` - deploy/google_api_token_data
- `RADIUS_KEY` - deploy/radius_key
- `RADIUS_IPS` - smoke_tests/radius_ips/london
- `NOTIFY_SMOKETEST_API_KEY` - smoketests/notify_smoketest_api_key

These are located in the govwifi-terraform repo
- `NOTIFY_GO_TEMPLATE_ID` - located in the 'smoke_tests' module, in locals for each environment.
- `GOVWIFI_PHONE_NUMBER` -  located in the 'govwifi' module for each environment and region
- `SMOKETEST_PHONE_NUMBER` - located in the 'smoke_tests' module, in locals for each environment.
- `NOTIFY_FIELD` - located in the 'smoke_tests' module for each environment.


## Notify Mocking
We now have a service called Notify_Pit (Notify Point in Time)
This mocks the Notify API and returns calls mimicking that API
This allows for more rapid testing
Its enabled as default, to use the real api set this variable
```
export NOTIFY_BASE_URL=https://api.notifications.service.gov.uk
```

Then run the tests:
```make test```

if you want to test the lib tests (currently only testing the SMS route) run
``` make test-lib```
This is what is used when the build github action runs.

Particularly when running in an automated remote way, these credentials should be for a dummy organisation/account, with limited access.

You can also run outside of Docker - in this case the tests run in "headed" mode - i.e. you can watch them run in the browser. First you should install dependencies:
```
brew install firefox
brew install geckodriver
bundle install
```

Then similar to above, except you run rspec directly:
```
bundle exec rspec
```

## Updating The Google API Token

Instructions for updating the [Google API token](https://github.com/GovWifi/govwifi-smoke-tests/blob/363d6827e4eb7763003d0d9f4fd4f4288c6fa28a/smoke-tests-concourse.yml#L136) [can be found here](https://docs.google.com/document/d/1uAaho6jRFUyBT4WRFuDN8pfDmHjfYvG6hT_uo4g1pqA/edit#heading=h.2q4zw5lc8jgj)

## Running The Smoke Tests In Our Environments

The smoke tests have now been migrated from Concourse to AWS. [Full instructions on how to run and edit the infrastructure around them can be found here](https://docs.google.com/document/d/1RHNkGxJLr4BPPUlFgqDzCF6mSOXK0Kj2Yfb-GHXXNIA/). You will need to be a member of the GovWifi Team in order to access this guide.

## Adding elastic-ips to GovWifi Admin
- From AWS environment, get `EC2 > Elastic IP Addresses` filtered by 'smoke'
- Fetch IP addresses from the column 'Allocated IPv4 address'
- Add IP addresses to GovWifi Admin (https://admin.SUBDOMAIN.service.gov.uk/ips)

## New Environments
If creating smoke tests on new environments, ensure to create new secrets for all appropriate fields, also new templates in Notify will need creating, as well as API keys.  For Radius ensure that it knows about the ```task``` ip's as well as the smoke test org ip's ```<env>.wifi-smoke-tests-x```, these will need to be entered into the Admin App for the Smoke Test Org.

### Generating the TLS certificates to test the CBA user Journey

The smoketests require that dummy certificates are generated to function correctly. You will need to create these if you are setting up a new GovWifi environment from scratch or testing locally. They are referenced through environment variables in the EAP TLS journey ([code](https://github.com/GovWifi/govwifi-smoke-tests/blob/cfb97ee543514209989e53b9001644c839570cc3/spec/system/signup/eap_tls_journey_spec.rb#L8-L14)) and they are referenced in the [govwifi-terraform code](https://github.com/GovWifi/govwifi-terraform/blob/f0fc070b4d0d281f8d721c64bf823b9fddf0cb0b/govwifi-smoke-tests/codebuild.tf#L110-L118)

You can generate them with the following steps:

* Make a directory called `smoke_test_certificates` or the directory name set in [this line of the Makefile](https://github.com/GovWifi/govwifi-smoke-tests/blob/4a182cbf609c43c4407dbea87ea956633d470c6c/Makefile#L3)
* Run `make certs` in your terminal
(If you need to edit these commands they can be found in [this section of the Smoketests Makefile](https://github.com/GovWifi/govwifi-smoke-tests/blob/4a182cbf609c43c4407dbea87ea956633d470c6c/Makefile#L65-L74))

If you are setting up a new GovWifi environment add these certificates to AWS secret manager. Name the secrets `smoke_tests/certificates/public` for the public key and `smoke_tests/certificates/private` for the private key.

[You can read more about CBA(Certificate Based Authentication) in our team manual](https://dev-docs.wifi.service.gov.uk/about-govwifi/device-wifi.html#what-is-it)

