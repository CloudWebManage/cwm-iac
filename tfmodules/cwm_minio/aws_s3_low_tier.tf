moved {
  from = random_password.low_tier_bucket_suffix
  to   = random_password.low_tier_bucket_suffix[0]
}

moved {
  from = aws_s3_bucket.low_tier
  to   = aws_s3_bucket.low_tier[0]
}

resource "random_password" "low_tier_bucket_suffix" {
  count            = var.create_low_tier_s3 ? 1 : 0
  length           = 16
  special          = false
  upper = false
}


resource "aws_s3_bucket" "low_tier" {
  count    = var.create_low_tier_s3 ? 1 : 0
  provider = aws.default
  bucket = "${var.cluster_name}-low-tier-${random_password.low_tier_bucket_suffix[0].result}"
  region = var.low_tier_s3_region
}

# manually:
# create iam policy "${var.cluster_name}-low-tier-s3"
# paste aws_s3_low_tier_policy.json (replace <BUCKET> with the bucket name)
# create user "${var.cluster_name}-low-tier-s3"
# attach the policy to the user
# create an access key for the user
# login to management vault
# create secret at kvv2/cwm-worker-cluster/${var.cluster_name}/low-tier-aws-s3
# set keys "access" and "secret"

output "low_tier_s3" {
  value = var.create_low_tier_s3 ? {
    aws_region = var.low_tier_s3_region
    bucket_name = aws_s3_bucket.low_tier[0].bucket
  } : null
}
