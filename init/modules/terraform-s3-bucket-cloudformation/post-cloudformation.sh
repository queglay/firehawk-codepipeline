
bucket_name="$(terragrunt output bucket_name)"

# terragrunt output s3_bucket_domain_name

# s3://cloudformation.dev.firehawkvfx.com/cloudformation_ssm_parameters_firehawk.yaml
# "s3://${bucket_name}/cloudformation_ssm_parameters_firehawk.yaml"

# https://s3.ap-southeast-2.cloudformation.dev.firehawkvfx.com.s3.amazonaws.com

# https://s3.eu-central-1.amazonaws.com/cloudformation-templates-eu-central-1/WordPress_Single_Instance.template

# "https://eu-central-1.console.aws.amazon.com/cloudformation/home?region=eu-central-1#/stacks/create/review
#    ?templateURL=https://s3.eu-central-1.amazonaws.com/cloudformation-templates-eu-central-1/WordPress_Single_Instance.template
#    &stackName=MyWPBlog
#    &param_DBName=mywpblog
#    &param_InstanceType=t2.medium
#    &param_KeyName=MyKeyPair"

template_url="https://s3.amazonaws.com/${bucket_name}/cloudformation_ssm_parameters_firehawk.yaml"

quick_create_url="https://console.aws.amazon.com/cloudformation/home?region=${AWS_DEFAULT_REGION}#/stacks/create/review?templateURL=${template_url}&stackName=SSMParametersFirehawk"

echo 
echo "If this is your first time setting up:"
echo "1. Follow the UBL Instructions"
echo "2. You must configure more parameters before deployment using the cloudformation template here:"
echo "${quick_create_url}"

# working
# https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-2#/stacks/create/review?templateURL=https://s3.amazonaws.com/cloudformation.dev.firehawkvfx.com/cloudformation_ssm_parameters_firehawk.yaml&stackName=SSMParametersFirehawk