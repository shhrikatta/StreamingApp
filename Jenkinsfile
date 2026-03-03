pipeline {
    agent any

    environment {
        AWS_REGION       = "${params.AWS_REGION ?: 'ap-south-1'}"
        AWS_ACCOUNT_ID   = credentials('aws-account-id')
        ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG        = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'latest'}"
        ECR_REPO_PREFIX  = 'streamingapp'
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region for ECR')
        string(name: 'REACT_APP_AUTH_API_URL', defaultValue: '', description: 'Auth API URL for frontend build')
        string(name: 'REACT_APP_STREAMING_API_URL', defaultValue: '', description: 'Streaming API URL for frontend build')
        string(name: 'REACT_APP_STREAMING_PUBLIC_URL', defaultValue: '', description: 'Streaming public URL for frontend build')
        string(name: 'REACT_APP_ADMIN_API_URL', defaultValue: '', description: 'Admin API URL for frontend build')
        string(name: 'REACT_APP_CHAT_API_URL', defaultValue: '', description: 'Chat API URL for frontend build')
        string(name: 'REACT_APP_CHAT_SOCKET_URL', defaultValue: '', description: 'Chat Socket URL for frontend build')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Create ECR Repositories') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    script {
                        def repos = [
                            "${ECR_REPO_PREFIX}/frontend",
                            "${ECR_REPO_PREFIX}/auth-service",
                            "${ECR_REPO_PREFIX}/streaming-service",
                            "${ECR_REPO_PREFIX}/admin-service",
                            "${ECR_REPO_PREFIX}/chat-service"
                        ]
                        repos.each { repo ->
                            sh """
                                aws ecr describe-repositories --repository-names ${repo} --region ${AWS_REGION} 2>/dev/null || \
                                aws ecr create-repository \
                                    --repository-name ${repo} \
                                    --region ${AWS_REGION} \
                                    --image-scanning-configuration scanOnPush=true \
                                    --image-tag-mutability MUTABLE
                            """
                        }
                    }
                }
            }
        }

        stage('ECR Login') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    """
                }
            }
        }

        stage('Build & Push Images') {
            parallel {
                stage('Auth Service') {
                    steps {
                        script {
                            def image = "${ECR_REGISTRY}/${ECR_REPO_PREFIX}/auth-service"
                            sh """
                                docker build -t ${image}:${IMAGE_TAG} -t ${image}:latest \
                                    -f backend/authService/Dockerfile \
                                    backend/authService
                                docker push ${image}:${IMAGE_TAG}
                                docker push ${image}:latest
                            """
                        }
                    }
                }

                stage('Streaming Service') {
                    steps {
                        script {
                            def image = "${ECR_REGISTRY}/${ECR_REPO_PREFIX}/streaming-service"
                            sh """
                                docker build -t ${image}:${IMAGE_TAG} -t ${image}:latest \
                                    -f backend/streamingService/Dockerfile \
                                    backend
                                docker push ${image}:${IMAGE_TAG}
                                docker push ${image}:latest
                            """
                        }
                    }
                }

                stage('Admin Service') {
                    steps {
                        script {
                            def image = "${ECR_REGISTRY}/${ECR_REPO_PREFIX}/admin-service"
                            sh """
                                docker build -t ${image}:${IMAGE_TAG} -t ${image}:latest \
                                    -f backend/adminService/Dockerfile \
                                    backend
                                docker push ${image}:${IMAGE_TAG}
                                docker push ${image}:latest
                            """
                        }
                    }
                }

                stage('Chat Service') {
                    steps {
                        script {
                            def image = "${ECR_REGISTRY}/${ECR_REPO_PREFIX}/chat-service"
                            sh """
                                docker build -t ${image}:${IMAGE_TAG} -t ${image}:latest \
                                    -f backend/chatService/Dockerfile \
                                    backend
                                docker push ${image}:${IMAGE_TAG}
                                docker push ${image}:latest
                            """
                        }
                    }
                }

                stage('Frontend') {
                    steps {
                        script {
                            def image = "${ECR_REGISTRY}/${ECR_REPO_PREFIX}/frontend"
                            def buildArgs = ''
                            if (params.REACT_APP_AUTH_API_URL) {
                                buildArgs += " --build-arg REACT_APP_AUTH_API_URL=${params.REACT_APP_AUTH_API_URL}"
                            }
                            if (params.REACT_APP_STREAMING_API_URL) {
                                buildArgs += " --build-arg REACT_APP_STREAMING_API_URL=${params.REACT_APP_STREAMING_API_URL}"
                            }
                            if (params.REACT_APP_STREAMING_PUBLIC_URL) {
                                buildArgs += " --build-arg REACT_APP_STREAMING_PUBLIC_URL=${params.REACT_APP_STREAMING_PUBLIC_URL}"
                            }
                            if (params.REACT_APP_ADMIN_API_URL) {
                                buildArgs += " --build-arg REACT_APP_ADMIN_API_URL=${params.REACT_APP_ADMIN_API_URL}"
                            }
                            if (params.REACT_APP_CHAT_API_URL) {
                                buildArgs += " --build-arg REACT_APP_CHAT_API_URL=${params.REACT_APP_CHAT_API_URL}"
                            }
                            if (params.REACT_APP_CHAT_SOCKET_URL) {
                                buildArgs += " --build-arg REACT_APP_CHAT_SOCKET_URL=${params.REACT_APP_CHAT_SOCKET_URL}"
                            }
                            sh """
                                docker build -t ${image}:${IMAGE_TAG} -t ${image}:latest \
                                    ${buildArgs} \
                                    -f frontend/Dockerfile \
                                    frontend
                                docker push ${image}:${IMAGE_TAG}
                                docker push ${image}:latest
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout ${ECR_REGISTRY} || true'
        }
        success {
            echo "All images pushed to ECR with tag: ${IMAGE_TAG}"
        }
        failure {
            echo 'Build or push failed. Check the logs for details.'
        }
    }
}
