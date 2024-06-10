locals { 
  region = "us-east-2" # Change to your own AWS region

  # List of S3 bucket names
  bucket_names = [
    "Name-Of-Your-S3-Bucket-1", # Replace with your first S3 bucket name
    "Name-Of-Your-S3-Bucket-2", # Replace with your second S3 bucket name
  ]

  # Template for S3 bucket policy that allows public read access
  public_read_policy_template = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadForGetBucketObjects",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::%s/*" # Placeholder for bucket name
        }
    ]
}
EOF
}
