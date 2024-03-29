locals {
  project = {
    name = "swit-alpha"
    id   = "swit-alpha"
  }

  regions = [
    "asia-northeast3",
    "us-west1"
  ]

  vpc_access_connectors = [
    { region = "us-west1", name = "swit-alpha-serverless-uw1" },
    { region = "us-weest1", name = "test-serverless-mysql" }
  ]
}
