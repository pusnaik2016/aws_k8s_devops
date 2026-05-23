"""
Seed data script for the DevOps Learning Quiz Application
Author: Pushparaj Naik
"""
from app import create_app
from app.models import db
from app.models.models import Topic, Question

app = create_app()

def seed_topics():
    """Seed initial topics"""
    topics = [
        {
            'name': 'Linux',
            'slug': 'linux',
            'description': 'Test your knowledge of Linux operating system, commands, and system administration'
        },
        {
            'name': 'Docker',
            'slug': 'docker',
            'description': 'Test your knowledge of Docker containerization, images, and container orchestration basics'
        },
        {
            'name': 'Kubernetes',
            'slug': 'kubernetes',
            'description': 'Test your knowledge of Kubernetes orchestration, pods, services, and cluster management'
        },
        {
            'name': 'AWS',
            'slug': 'aws',
            'description': 'Test your knowledge of Amazon Web Services cloud platform and its services'
        },
        {
            'name': 'Jenkins',
            'slug': 'jenkins',
            'description': 'Test your knowledge of Jenkins CI/CD, pipelines, and automation'
        }
    ]

    for topic_data in topics:
        existing = Topic.query.filter_by(slug=topic_data['slug']).first()
        if not existing:
            topic = Topic(**topic_data)
            db.session.add(topic)
            print(f"Added topic: {topic_data['name']}")
        else:
            print(f"Topic already exists: {topic_data['name']}")

    db.session.commit()

def seed_sample_questions():
    """Seed some sample questions for each topic"""
    sample_questions = {
        'linux': [
            {
                'question_text': 'Which command is used to change file permissions in Linux?',
                'options': ['chmod', 'chown', 'chgrp', 'chperm'],
                'correct_answer': 0
            },
            {
                'question_text': 'What does the command "ps aux" do?',
                'options': ['Shows disk usage', 'Lists all running processes', 'Shows network connections', 'Displays system logs'],
                'correct_answer': 1
            },
            {
                'question_text': 'Which file contains user account information in Linux?',
                'options': ['/etc/shadow', '/etc/group', '/etc/passwd', '/etc/users'],
                'correct_answer': 2
            }
        ],
        'docker': [
            {
                'question_text': 'What is the default network driver in Docker?',
                'options': ['host', 'overlay', 'bridge', 'none'],
                'correct_answer': 2
            },
            {
                'question_text': 'Which command is used to build a Docker image?',
                'options': ['docker create', 'docker build', 'docker make', 'docker compile'],
                'correct_answer': 1
            },
            {
                'question_text': 'What is a Docker volume used for?',
                'options': ['Running containers', 'Storing network configs', 'Persisting data', 'Managing images'],
                'correct_answer': 2
            }
        ],
        'kubernetes': [
            {
                'question_text': 'What is the smallest deployable unit in Kubernetes?',
                'options': ['Container', 'Node', 'Pod', 'Service'],
                'correct_answer': 2
            },
            {
                'question_text': 'Which Kubernetes object is used for service discovery and load balancing?',
                'options': ['Deployment', 'Service', 'ConfigMap', 'Ingress'],
                'correct_answer': 1
            },
            {
                'question_text': 'What is a Kubernetes namespace used for?',
                'options': ['Resource isolation', 'Data storage', 'Network routing', 'Container building'],
                'correct_answer': 0
            }
        ],
        'aws': [
            {
                'question_text': 'Which AWS service is used for object storage?',
                'options': ['EBS', 'EFS', 'S3', 'Glacier'],
                'correct_answer': 2
            },
            {
                'question_text': 'What is the maximum size of an S3 object?',
                'options': ['1 TB', '5 TB', '10 TB', 'Unlimited'],
                'correct_answer': 1
            },
            {
                'question_text': 'Which AWS service provides managed Kubernetes?',
                'options': ['ECS', 'EKS', 'Lambda', 'Fargate'],
                'correct_answer': 1
            }
        ],
        'jenkins': [
            {
                'question_text': 'What is a Jenkinsfile?',
                'options': ['Configuration file', 'Pipeline definition', 'Plugin manifest', 'Log file'],
                'correct_answer': 1
            },
            {
                'question_text': 'Which plugin is commonly used for Git integration in Jenkins?',
                'options': ['Git Plugin', 'SVN Plugin', 'Mercurial Plugin', 'CVS Plugin'],
                'correct_answer': 0
            },
            {
                'question_text': 'What is a Jenkins agent?',
                'options': ['A user account', 'A machine that runs builds', 'A notification system', 'A backup server'],
                'correct_answer': 1
            }
        ]
    }

    for topic_slug, questions in sample_questions.items():
        topic = Topic.query.filter_by(slug=topic_slug).first()
        if topic:
            existing_count = Question.query.filter_by(topic_id=topic.id).count()
            if existing_count == 0:
                for q_data in questions:
                    question = Question(
                        topic_id=topic.id,
                        question_text=q_data['question_text'],
                        options=q_data['options'],
                        correct_answer=q_data['correct_answer']
                    )
                    db.session.add(question)
                print(f"Added {len(questions)} sample questions for {topic_slug}")
            else:
                print(f"Questions already exist for {topic_slug}")

    db.session.commit()

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        seed_topics()
        seed_sample_questions()
        print("Seeding completed successfully!")
