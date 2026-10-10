import boto3

"""
~/.aws/credentials
[account]
aws_access_key_id=XXXX
aws_secret_access_key=XXXX


~/.aws/config
[account]
region=eu-central-1
output=json

"""


prod_profile_name = "ecs-prod"
region = "eu-central-1"

prod_bucket_name = prod_profile_name + "-tfstate"


production = boto3.Session(profile_name=prod_profile_name, region_name=region)


def bootstrap(bucket_name, environment_session, aws_region):
    s3 = environment_session.resource("s3")
    s3_client = environment_session.client("s3")
    bucket = s3.Bucket(bucket_name)

    if bucket.creation_date:
        print(
            "The "
            + environment_session.profile_name
            + " environment bucket: "
            + bucket_name
            + " exists"
        )
    else:
        print(
            "The "
            + environment_session.profile_name
            + " bucket: "
            + bucket_name
            + " does not exist"
        )
        bucket = s3_client.create_bucket(
            Bucket=bucket_name,
            CreateBucketConfiguration={"LocationConstraint": aws_region},
            ACL="private",
        )
        print(bucket)

    # Idempotent hardening for a Terraform state bucket:
    # - block all public access
    # - versioning, so a corrupted/deleted state file can be recovered
    # - SSE-S3 encryption at rest (the backend also sends encrypt = true)
    response = s3_client.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        },
    )
    print(response)

    response = s3_client.put_bucket_versioning(
        Bucket=bucket_name,
        VersioningConfiguration={"Status": "Enabled"},
    )
    print(response)

    response = s3_client.put_bucket_encryption(
        Bucket=bucket_name,
        ServerSideEncryptionConfiguration={
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
                    "BucketKeyEnabled": True,
                }
            ]
        },
    )
    print(response)


bootstrap(prod_bucket_name, production, region)
