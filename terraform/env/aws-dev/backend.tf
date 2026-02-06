terraform {
  backend "s3" {
    bucket         = "bankit-cloud-terraform-state"
    key            = "ibank/aws-dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
