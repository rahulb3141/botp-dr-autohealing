pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_VAR_project_name = 'dr-demo'
        TF_VAR_primary_region = 'us-east-1'
        TF_VAR_secondary_region = 'us-east-1'
        TF_VAR_existing_vpc_name = 'eks-vpc'
        // TF_VAR_domain_name = 'mydrdemo.local'
    }
    
    stages {
        stage('Setup Environment') {
            steps {
                script {
                    echo "🔧 Setting up environment..."
                    sh 'chmod +x scripts/*.sh'
                    sh './scripts/setup-environment.sh'
                }
            }
        }
        
        stage('Terraform Plan - Primary Region') {
            steps {
                script {
                    echo "📋 Planning Terraform for Primary Region..."
                    dir('terraform/primary-region') {
                        sh 'terraform init'
                        sh 'terraform validate'
                        sh 'terraform plan -out=tfplan'
                    }
                }
            }
        }
        
        stage('Terraform Apply - Primary Region') {
            steps {
                script {
                    echo "🚀 Applying Terraform for Primary Region..."
                    dir('terraform/primary-region') {
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }
        
        stage('Terraform Plan - Secondary Region') {
            steps {
                script {
                    echo "📋 Planning Terraform for Secondary Region..."
                    dir('terraform/secondary-region') {
                        sh 'terraform init'
                        sh 'terraform validate'
                        sh 'terraform plan -out=tfplan'
                    }
                }
            }
        }
        
        stage('Terraform Apply - Secondary Region') {
            steps {
                script {
                    echo "🚀 Applying Terraform for Secondary Region..."
                    dir('terraform/secondary-region') {
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }
        
        stage('Deploy Kubernetes - Primary') {
            steps {
                script {
                    echo "☸️ Deploying to Primary EKS Cluster..."
                    sh './scripts/deploy-primary.sh'
                }
            }
        }
        
        stage('Deploy Kubernetes - Secondary') {
            steps {
                script {
                    echo "☸️ Deploying to Secondary EKS Cluster..."
                    sh './scripts/deploy-secondary.sh'
                }
            }
        }
        
        stage('Validate Infrastructure') {
            steps {
                script {
                    echo "✅ Validating infrastructure..."
                    sh './scripts/backup-validation.sh'
                }
            }
        }
        
        stage('Test DR Failover') {
            steps {
                script {
                    echo "🧪 Testing disaster recovery failover..."
                    sh './scripts/test-failover.sh'
                }
            }
        }
        
        stage('Cleanup Test Resources') {
            when {
                expression { params.CLEANUP_AFTER_TEST == true }
            }
            steps {
                script {
                    echo "🧹 Cleaning up test resources..."
                    sh './scripts/cleanup.sh'
                }
            }
        }
    }
    
    parameters {
        booleanParam(
            name: 'CLEANUP_AFTER_TEST',
            defaultValue: false,
            description: 'Clean up resources after testing'
        )
        choice(
            name: 'TERRAFORM_ACTION',
            choices: ['apply', 'plan', 'destroy'],
            description: 'Terraform action to perform'
        )
    }
    
    post {
        always {
            echo "📊 DR pipeline completed"
            archiveArtifacts artifacts: 'logs/*.log, terraform/**/*.tfplan', allowEmptyArchive: true
        }
        success {
            echo "✅ DR pipeline passed successfully"
        }
        failure {
            echo "❌ DR pipeline failed"
            script {
                // Cleanup on failure
                sh './scripts/cleanup-on-failure.sh || true'
            }
        }
    }
}
