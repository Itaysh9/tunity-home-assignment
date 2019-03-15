# tunity-home-assignment

This repo includes terraform manifest that deploys kubernetes cluster on GKE and a nginx on that cluster exposed externally.

## Deployment

To deploy clone the repo and run the folowing commands:

Initialize the terraform plugins
```console
$ terraform init
```

Apply the terraform

```console
$ terraform apply -auto-approve -var 'project=gcp_project_name' -var 'region=your_region' -var 'cred_file_path=google_service_account_file' 
```


After all the resources are created you can use google cloud dashboard or configure kubectl to your cluster to get the external ip.