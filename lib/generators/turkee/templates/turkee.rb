AWSACCESSKEYID      = 'XXXXXXXXXXXXXXXXXX'
AWSACCESSKEY        = 'YYYYYYYYYYYYYYYYYYYYYYYYYYYY'

RTurk::logger.level = Logger::DEBUG
RTurk.setup(AWSACCESSKEYID, AWSACCESSKEY, :sandbox => (Rails.env == 'production' ? false : true))