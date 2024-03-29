variable "project" {
  type = object({
    name = string
    id   = string
  })
}

variable "regions" {
  type = list(string)
}

variable "vpc_access_connectors" {
  type = list(object({
    region = string
    name   = string
  }))
}
