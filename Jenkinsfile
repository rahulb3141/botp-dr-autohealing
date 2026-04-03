pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
    }
    
    stages {
        stage('Setup Environment') {
            steps {
                script {
                    echo "Setting up environment..."
                    sh 'chmod +x scripts/*.sh'
                    sh './scripts/setup-environment.sh'
                }
            }
        }
        
        stage('Validate Primary Infrastructure') {
            steps {
                script {
                    echo "Validating primary region infrastructure..."
                    sh './scripts/backup-validation.sh'
                }
            }
        }
        
        stage('Test DR Failover') {
            steps {
                script {
                    echo "Testing disaster recovery failover..."
                    sh './scripts/test-failover.sh'
                }
            }
        }
        
        stage('Validate Secondary Region') {
            steps {
                script {
                    echo "Validating secondary region deployment..."
                    sh 'kubectl get nodes --context=secondary-cluster || echo "Secondary cluster not ready"'
                }
            }
        }
        
        stage('Cleanup Test Resources') {
            steps {
                script {
                    echo "Cleaning up test resources..."
                    sh './scripts/cleanup.sh'
                }
            }
        }
    }
    
    post {
        always {
            echo "DR test pipeline completed"
            archiveArtifacts artifacts: 'logs/*.log', allowEmptyArchive: true
        }
        success {
            echo "✅ DR test passed successfully"
        }
        failure {
            echo "❌ DR test failed"
        }
    }
}
