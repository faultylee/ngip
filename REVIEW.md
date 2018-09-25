# Interview Take Home Project
## Review 2018-09-25

I've found a bug with the build script where I was using the pipe `|` instead of ORing with `||` to ignore errors with the `terraform destroy` commands. I've also missed out provided some required variable to terraform in the destroy script resulting it terraform not being able to destroy the stack. It's all good now and I managed to extract a complete build log with terraform apply from cold start to destroy in one single process.

The state of the code discussed here is in the `review-2018-09-25` branch.    