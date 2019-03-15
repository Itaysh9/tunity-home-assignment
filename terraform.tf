provider "google" {
  credentials = "${file("${var.cred_file_path}")}"
  project     = "${var.project}"
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host = "${google_container_cluster.primary.endpoint}"
  load_config_file = false
  token = "${data.google_client_config.default.access_token}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
}

resource "google_container_cluster" "primary" {
  name = "tunity-home-test-cluster"
  region      = "${var.region}"
  remove_default_node_pool = true
  initial_node_count = 1

  # Setting an empty username and password explicitly disables basic auth
  master_auth {
    username = ""
    password = ""
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "tunity-home-test-node-pool"
  region     = "${var.region}"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = 1

  node_config {
    machine_type = "n1-standard-1"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "tunity"
  }
    depends_on = ["google_container_node_pool.primary_nodes"]
}

resource "kubernetes_deployment" "deployment" {
  metadata {
    name = "nginx"
	namespace = "${kubernetes_namespace.namespace.metadata.0.name}"
    labels {
      app = "nginx"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels {
          app = "nginx"
        }
      }

      spec {
        container {
          image = "nginx:1.15"
          name  = "nginx"

          resources{
            limits{
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests{
              cpu    = "250m"
              memory = "256Mi"
            }
          }
		  volume_mount {
			mount_path = "/etc/nginx/conf.d"
			name = "config"
		  }
        }
		volume {
			name = "config"
			config_map {
				name = "${kubernetes_config_map.config_map.metadata.0.name}"
			}	
		}
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "hpa" {
  metadata {
    name = "nginx"
	namespace = "${kubernetes_namespace.namespace.metadata.0.name}"
	
  }
  spec {
    max_replicas = 10
    min_replicas = 2
    scale_target_ref {
      kind = "deployment"
      name = "${kubernetes_deployment.deployment.metadata.0.name}"
	  api_version = "extensions/v1beta1"
    }
	target_cpu_utilization_percentage = 85
  }
}

resource "kubernetes_service" "service" {
  metadata {
    name = "nginx"
	namespace = "${kubernetes_namespace.namespace.metadata.0.name}"
  }
  spec {
    selector {
      app = "${kubernetes_deployment.deployment.spec.0.template.0.metadata.0.labels.app}"
    }
    port {
      port = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_config_map" "config_map" {
  metadata {
    name = "nginx"
	namespace = "${kubernetes_namespace.namespace.metadata.0.name}"
  }

  data {
    nginx.conf = "${file("tunity.conf")}"
  }
}