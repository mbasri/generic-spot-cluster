{
  "ResourceTypeFilters": [
    "AWS::EC2::Instance"
  ],
  "TagFilters": [
    {
      "Key": "Technical:ECSClusterName",
      "Values": ["${ecs_cluster_name}"]
    }
  ]
}