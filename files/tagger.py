import os
import sys
import logging
import boto3

def handler(event, context):
  logger = setup_logging(context.aws_request_id)
  logger.setLevel(logging.INFO)

  logger.info('## ENVIRONMENT VARIABLES')
  logger.info(os.environ)
  logger.info('## EVENT')
  logger.info(event)
  
  count = '1'
  CLUSTER_NAME = os.environ['cluster_name']

  asg = boto3.client('autoscaling')
  ec2 = boto3.client('ec2')

  asg_response = asg.describe_auto_scaling_groups(
    AutoScalingGroupNames=[
      CLUSTER_NAME
    ]
  )
  
  instances = []
  
  try:
    for i in asg_response['AutoScalingGroups'][0]['Instances']:
      if i['LifecycleState'] == 'InService' or i['LifecycleState'] == 'Pending': 
        instances.append(i['InstanceId'])
  except IndexError :
    logger.error('IndexError on autoscaling')
    count = '1'
    
  logger.info('## INSTANCE(S) FOUND ON THE ASG')
  logger.info('instances=['+','.join(instances)+']')
  
  ec2_response = ec2.describe_instances(
    Filters=[
        {
            'Name': 'instance-state-name',
            'Values': [
                'pending',
                'running',
                'stopping',
                'stopped',
            ]
        },
        {
            'Name': 'tag-key',
            'Values': [
                'Count',
            ]
        }
    ],
    InstanceIds = instances
  )
  logger.info('## ACTIVE INSTANCE(S) FOUND ON THE ASG')
  logger.info('ec2_response='+str(ec2_response))
  
  counts = []
  try :
    for i in ec2_response['Reservations']:
      for j in i['Instances']:
        for z in j['Tags']:
          if z['Key'] == 'Count':
            counts.append(z['Value'])
  except IndexError :
    logger.error('IndexError on ec2')
    count = '1'
    
  #counts.sort()
  for i in counts :
    if count in counts:
      count = str(int(count)+1)
    else:
      break

  ec2.create_tags(
    Resources = [
      event['instance_id']
      ], 
    Tags=[
      {
        'Key': 'Count',
        'Value': count
      }
    ]
  )

  response = {
    'cluster_name': CLUSTER_NAME,
    'count': count,
    'instance_id': event['instance_id']
  }

  logger.info('## RESPONSE')
  logger.info('response' + str(response))

  return response

def setup_logging(uuid):
  logger = logging.getLogger()
  for handler in logger.handlers:
    logger.removeHandler(handler)
  
  handler = logging.StreamHandler(sys.stdout)
  formatter = f"[%(asctime)s] [Bastion] [{uuid}] [%(levelname)s] %(message)s"
  handler.setFormatter(logging.Formatter(formatter))
  logger.addHandler(handler)
  logger.setLevel(logging.DEBUG)
  
  return logger