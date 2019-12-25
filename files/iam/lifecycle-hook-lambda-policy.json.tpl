{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "autoscaling:CompleteLifecycleAction",
                "ecs:UpdateContainerInstancesState",
                "ecs:ListContainerInstances",
                "ecs:DescribeContainerInstances",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}