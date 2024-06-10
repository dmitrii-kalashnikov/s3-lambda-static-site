import boto3
import json
import urllib3
import os

def update_bucket_policy(bucket_name, ip_list):
    s3 = boto3.client('s3')
    bucket_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "PublicReadForGetBucketObjects",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": f"arn:aws:s3:::{bucket_name}/*",
                "Condition": {
                    "IpAddress": {
                        "aws:SourceIp": ip_list
                    }
                }
            }
        ]
    }
    bucket_policy = json.dumps(bucket_policy)
    s3.put_bucket_policy(Bucket=bucket_name, Policy=bucket_policy)

def lambda_handler(event, context):
    # CloudFlare connection
    http = urllib3.PoolManager()
    r = http.request('GET', 'https://api.cloudflare.com/client/v4/ips')
    json_content = json.loads(r.data)
    ipv4 = json_content["result"]["ipv4_cidrs"]
    ipv6 = json_content["result"]["ipv6_cidrs"]
    ip_list = ipv4 + ipv6
    
    # Get bucket names from environment variable
    bucket_names = os.environ.get('BUCKET_NAME', '').split(',')
    if not bucket_names[0]:
        return {
            'statusCode': 400,
            'body': 'BUCKET_NAMES not set.'
        }
    
    # Update policy for each bucket
    for bucket_name in bucket_names:
        update_bucket_policy(bucket_name, ip_list)
