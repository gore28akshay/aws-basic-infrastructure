# aws-basic-infrastructure

AWS basic infrastucture components using resources and not modules. List of components.
a.  VPC (10.0.0.0/26)
b.  Subnets (public[10.0.0.32/27] and private[10.0.0.0/27] )
c.  NAT Gateway
d.  NAT to IGW association
e.  public route table association to default route table
f.  private route table association to private route table
g.  EC2 instance in both subnets
h.  security groups for both ec2 instances and ALB
