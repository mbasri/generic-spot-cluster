import os
import sys
import logging
import json
import time
import boto3

ECS = boto3.client('ecs')
ASG = boto3.client('autoscaling')
SNS = boto3.client('sns')

def find_ecs_instance_info(instance_id, CLUSTER):
    paginator = ECS.get_paginator('list_container_instances')
    for list_resp in paginator.paginate(cluster=CLUSTER):
        arns = list_resp['containerInstanceArns']
        desc_resp = ECS.describe_container_instances(cluster=CLUSTER,
                                                     containerInstances=arns)
        for container_instance in desc_resp['containerInstances']:
            if container_instance['ec2InstanceId'] != instance_id:
                continue
            logger.info('Found instance: id=%s, arn=%s, status=%s, runningTasksCount=%s' %
                  (instance_id, container_instance['containerInstanceArn'],
                   container_instance['status'], container_instance['runningTasksCount']))
            return (container_instance['containerInstanceArn'],
                    container_instance['status'], container_instance['runningTasksCount'])
    return None, None, 0

def instance_has_running_tasks(instance_id, CLUSTER):
    (instance_arn, container_status, running_tasks) = find_ecs_instance_info(instance_id, CLUSTER)
    if instance_arn is None:
        logger.info('Could not find instance ID %s. Letting autoscaling kill the instance.' %
              (instance_id))
        return False
    if container_status != 'DRAINING':
        logger.info('Setting container instance %s (%s) to DRAINING' %
              (instance_id, instance_arn))
        ECS.update_container_instances_state(cluster=CLUSTER,
                                             containerInstances=[instance_arn],
                                             status='DRAINING')
    return running_tasks > 0

def setup_logging(uuid):
  logger = logging.getLogger()
  for handler in logger.handlers:
    logger.removeHandler(handler)
  
  handler = logging.StreamHandler(sys.stdout)
  formatter = f"[%(asctime)s] [Lifecycle hook] [{os.environ['cluster_name']}] [{uuid}] [%(levelname)s] %(message)s"
  handler.setFormatter(logging.Formatter(formatter))
  logger.addHandler(handler)
  logger.setLevel(logging.DEBUG)
  
  return logger

def handler(event, context):
    global logger
    logger = setup_logging(context.aws_request_id)
    logger.setLevel(logging.INFO)

    msg = json.loads(event['Records'][0]['Sns']['Message'])
    clustername = os.environ['cluster_name'] #msg['NotificationMetadata']
    if 'LifecycleTransition' not in msg.keys() or \
       msg['LifecycleTransition'].find('autoscaling:EC2_INSTANCE_TERMINATING') == -1:
        logger.info('Exiting since the lifecycle transition is not EC2_INSTANCE_TERMINATING.')
        return
    if instance_has_running_tasks(msg['EC2InstanceId'], clustername):
        logger.info('Tasks are still running on instance %s; posting msg to SNS topic %s' %
              (msg['EC2InstanceId'], event['Records'][0]['Sns']['TopicArn']))
        time.sleep(10)
        sns_resp = SNS.publish(TopicArn=event['Records'][0]['Sns']['TopicArn'],
                               Message=json.dumps(msg),
                               Subject='Publishing SNS msg to invoke Lambda again.')
        logger.info('Posted msg %s to SNS topic.' % (sns_resp['MessageId']))
    else:
        logger.info('No tasks are running on instance %s; setting lifecycle to complete' %
              (msg['EC2InstanceId']))
        ASG.complete_lifecycle_action(LifecycleHookName=msg['LifecycleHookName'],
                                      AutoScalingGroupName=msg['AutoScalingGroupName'],
                                      LifecycleActionResult='CONTINUE',
                                      InstanceId=msg['EC2InstanceId'])
