# Overview

This is a demo of the Confluent Terraform provider based in the official
Confluent [Sample Project for Confluent Terraform Provider].

# Setup

Create the environment variables with CCloud API key and secret:

```sh
export TF_VAR_confluent_cloud_api_key="XXX"
export TF_VAR_confluent_cloud_api_secret="YYY"
```

Review and apply:

```sh
terraform plan
terraform apply
```

It's possible to see the output with:

```sh
terraform output resource-ids
```

# Test it with the Confluent CLI

Produce:

```sh
confluent kafka topic produce orders --environment <ENV-ID> --cluster <CLUSTER-ID> --api-key <API-KEY> --api-secret <API-SECRET>
```

And send records:

> {"number":1,"date":18500,"shipping_address":"899 W Evelyn Ave, Mountain View, CA 94041, USA","cost":15.00}
> {"number":2,"date":18501,"shipping_address":"1 Bedford St, London WC2E 9HG, United Kingdom","cost":5.00}
> {"number":3,"date":18502,"shipping_address":"3307 Northland Dr Suite 400, Austin, TX 78731, USA","cost":10.00}

Consume:

```sh
confluent kafka topic consume orders --from-beginning --environment <ENV-ID> --cluster <CLUSTER-ID> --api-key <API-KEY> --api-secret <API-SECRET>
```

# Test it with Java Apps

Based on [Java: Code Example for Apache Kafka], it's possible to create the app
config to connect to the cluster using the Confluent CLI:

```sh
confluent kafka client-config create java --environment <ENV-ID> --cluster <CLUSTER-ID> --api-key=<API-KEY> --api-secret=<API-SECRET> > producer.config
```

You can use the demo apps in `../../otel-demo/`. It's also required for the
consumer and KStreams application.

[Sample Project for Confluent Terraform Provider]: https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/sample-project
[Java: Code Example for Apache Kafka]: https://docs.confluent.io/platform/current/tutorials/examples/clients/docs/java.html
