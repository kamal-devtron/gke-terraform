# Configure the GCP provider
provider "google" {
  credentials = file("./sa.json")
  project     = "project_id"
  region      = "asia-south1"
}

# Create a VPC network
resource "google_compute_network" "my_vpc" {
  name                    = "my-vpc"
  auto_create_subnetworks = false
}

# Create a subnet within the VPC
resource "google_compute_subnetwork" "public-subnet1" {
  name          = "public-subnet1"
  network       = google_compute_network.my_vpc.id
  ip_cidr_range = "10.0.32.0/20"
  region        = "asia-south1"
}
resource "google_compute_subnetwork" "public-subnet2" {
  name          = "public-subnet2"
  network       = google_compute_network.my_vpc.id
  ip_cidr_range = "10.0.48.0/20"
  region        = "asia-south1"
}
resource "google_compute_subnetwork" "private-subnet1" {
  name          = "private-subnet1"
  network       = google_compute_network.my_vpc.id
  ip_cidr_range = "10.0.0.0/20"
  region        = "asia-south1"
}
resource "google_compute_subnetwork" "private-subnet2" {
  name          = "private-subnet2"
  network       = google_compute_network.my_vpc.id
  ip_cidr_range = "10.0.16.0/20"
  region        = "asia-south1"
}




# Create a firewall rule to allow incoming traffic
resource "google_compute_firewall" "my_firewall" {
  name    = "my-firewall"
  network = google_compute_network.my_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Output the VPC details
output "vpc_details" {
  value = google_compute_network.my_vpc
}

# Create router For your VPC


# resource "google_compute_router_nat" "nat-gateway" {
#   name                  = "my-nat"
#   router                = google_compute_router.router.name
#   nat_ip_allocate_option = "AUTO_ONLY"
#   region                = "asia-south1"
#   source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
# }



resource "google_service_account" "default" {
  account_id   = "project_id"   #Required
  display_name = "<display_name>"

}

resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = "asia-south1"

  network       = google_compute_network.my_vpc.id
  subnetwork = google_compute_subnetwork.private-subnet1.id
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

#Devtron Nodes
resource "google_container_node_pool" "devtron-nodes" {
  name       = "devtron-nodes"
  cluster    = google_container_cluster.primary.id
  node_count =  1    #Desired Capacity
  

  node_config {
    preemptible  = false
    machine_type = "e2-standard-4"
    disk_size_gb = 50
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    # service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
   
    tags = ["component" , "cicd"]
  }
  
  autoscaling {
     min_node_count = 2
    max_node_count = 5
  }
  network_config {
    enable_private_nodes = true
  }
 
}

#Ci nodes
resource "google_container_node_pool" "ci-nodes" {
  name       = "ci-nodes"
  cluster    = google_container_cluster.primary.id
  node_count = 1   #Desired Capacity

  node_config {
    preemptible  = true
    machine_type = "e2-standard-4"
    disk_size_gb= 50
    
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    # service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
   labels = {
      purpose = "ci",
      app= "devtron"
    }
    tags = ["component" , "cicd"]
 
 
  }
 
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
  network_config {
    enable_private_nodes = true
  }
}