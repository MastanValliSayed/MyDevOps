#!groovy
@Library('itss-shared-lib@master')
def gitInfo = {}
def causes
def user

pipeline {

        agent { label 'DSLAVE2' }

        options {
            skipDefaultCheckout()
        }

        parameters {
        /*booleanParam(description: 'nexusIQscanNeeded', name: 'nexusIQscanNeeded')
        booleanParam(description: 'JTESTscanNeeded', name: 'JTESTscanNeeded')
        booleanParam(description: 'Will Be deployed only to SIT', name: 'DeployNeeded')
        booleanParam(description: 'CreateJIRATicket', name: 'CreateJIRATicket')
        booleanParam(description: 'NexusUpload', name: 'NexusUpload')*/
        string(name: 'BRANCH_NAME', defaultValue: '', description: 'Branch Name')
        string(name: 'MODULE', defaultValue: '', description: 'Enter MODULE')
        string(name: 'JIRA_KEY', defaultValue: '', description: 'Enter JIRA KEY')
            choice(
        name: 'DEPLOYMENT_MODULE',
        choices: "filecopy\nall\nmariadb",
        description: 'Deployment_Module' )
            choice(
        name: 'FILECOPY_MODULE',
        choices: "[Files]\n[Apps]\n[Config]\n[Scripts]\n[Files, Apps]\n[Files, Config]\n[Files, Apps, Config, Scripts]",
        description: 'Please select Deployment type ex: [Files, Apps, Config]' )
        }

        stages {

            stage('SourceCode-Checkout') {
               steps {

                    script {
                        //gitInfo = checkout([$class: 'GitSCM', branches: [[name: '*/dev']], doGenerateSubmoduleConfigurations: false, extensions: [], gitTool: 'SYSTEM', submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'b908cf13-35bb-4e2e-8781-56959264d385', url: 'https://bitbucket.sgp.dbs.com:8443/dcifgit/scm/ipe_mtx99/ipe-mt.git']]])
                        gitInfo = checkout scm
                        println gitInfo
                        println gitInfo.GIT_BRANCH
                        println gitInfo.GIT_COMMIT
                        Release_Version = "IPE_MTX99_UAT_"+env.BUILD_NUMBER
                        causes = currentBuild.getBuildCauses()
                        user = causes.userId[0];
                    }
                 }
            }

            stage('Build with maven') {
                steps {
                    script {

                        dir('src/ipe-mt-x99-gui/src'){
                         sh "npm install"
                        }
                        dir('src'){
                       
                        sh  """

                            mvn -P ${MODULE} clean package -DskipTest -Dmaven.test.skip=true
                            
                          """
                        }
                    }
               }
            }
            stage('Packaging'){
                steps{
                    script{
                        
                        sh """
                        mkdir -p ${WORKSPACE}/package/
                        #cp ${WORKSPACE}/src/ipe-mt-x99-api/target/ipe-mt-x99-api.war ${WORKSPACE}/package/
                        #cp ${WORKSPACE}/src/ipe-mt-x99-gui/src/target/ipe-mt-x99-gui.war ${WORKSPACE}/package/
                        cp ${WORKSPACE}/src/ipe-mt-x99-api/target/ipe-mt-x99-api*.war ${WORKSPACE}/package/
                        cp ${WORKSPACE}/src/ipe-mt-x99-gui/src/target/ipe-mt-x99-gui*.war ${WORKSPACE}/package/
                       touch "${DEPLOYMENT_MODULE}.module.dodeploy"
                       touch "${FILECOPY_MODULE}.filecopymodule.dodeploy"
                       echo ${MODULE} > module.txt
                       mv ${WORKSPACE}/deployment/config ${WORKSPACE}/config
                       mv ${WORKSPACE}/deployment/filecopy ${WORKSPACE}/filecopy
                       zip -r filecopy.zip package config filecopy "${DEPLOYMENT_MODULE}.module.dodeploy" "${FILECOPY_MODULE}.filecopymodule.dodeploy"
                       cd ${WORKSPACE}/deployment
                       zip -r deploymentProperties.zip filecopy.sh deploy.json
                       mv deploymentProperties.zip ${WORKSPACE}/
                        """
                    }
                }
            }
            stage('UploadPackage to Nexus repo') {
            steps {
                script {
                        //println "Nexus Upload"
                       nexusArtifactUploader artifacts: [[artifactId: 'filecopy', file: "${WORKSPACE}/filecopy.zip", type: 'zip']],
                                                                                credentialsId: 'nexusArtifactUploader',
                                                                                groupId: 'com.dbs.ibgt',
                                                                                nexusUrl: 'nexuscimgmt.sgp.dbs.com:8443/nexus',
                                                                                nexusVersion: 'nexus3',
                                                                                protocol: 'https',
                                                                                repository: 'IPE_MTX99',
                                                                                version: Release_Version
                          nexusArtifactUploader artifacts: [[artifactId: 'deploymentProperties', file: "${WORKSPACE}/deploymentProperties.zip", type: 'zip']],
                                                                                credentialsId: 'nexusArtifactUploader',
                                                                                groupId: 'com.dbs.ibgt',
                                                                                nexusUrl: 'nexuscimgmt.sgp.dbs.com:8443/nexus',
                                                                                nexusVersion: 'nexus3',
                                                                                protocol: 'https',
                                                                                repository: 'IPE_MTX99',
                                                                                version: Release_Version
                                                                                

                }
            }
            }

            stage('OSS-Scan'){
                steps{
                    script{
                        Map iqmp = [ commitID: gitInfo.GIT_COMMIT,
                            branch: gitInfo.GIT_BRANCH,
                            repourl: gitInfo.GIT_URL,
                            scantarget: "filecopy.zip",
                            iqProjectName: "IPE_MTX99",
                            organization: "MAS_or_External",
                            appCategory: "Hosted",
                            mailto: "guntupalli1@dbs.com,mastanvalli@dbs.com"      
                        ]
                        if (user.toString().equals("pdcifjirajnkfid") || user.toString().equals("mastanvalli")){
                           // performIQScan(iqmp)
                        }else{
                            ansiColor('xterm') {
                                //println iqmp
                                //println "\u001B[31m Triggered by $user so IQ Scan has been skipped\u001B[0m";
                            }
                        }
                    }
                }
            }

            stage('Sonar-Scan'){
                steps{
                    script{
                        Map sonarmp = [commitID: gitInfo.GIT_COMMIT,
                            branch: gitInfo.GIT_BRANCH,
                            repourl: gitInfo.GIT_URL,
                            "sonar.projectKey": "IPE_MTX99",
                            "sonar.projectName": "IPE_MTX99",
                            "sonar.branch.name": gitInfo.GIT_BRANCH,
                            "sonar.sources": ".",
                            "sonar.java.binaries": ".",
                           "sonar.exclusions": "**/vendor.js,**/node_modules/**,**/*.groovy,**/*.sql,**/*.SQL,**/*.Groovy,**/*.html,**/*.HTML,**/*.xml,**/*.XML,**/*.CSS,**/*.css,**/*.js",
                            qualityGateCheck: false
                        ]
                        if (user.toString().equals("pdcifjirajnkfid") || user.toString().equals("mastanvalli")){
                            //performSonarScan(sonarmp) 
                        }else{
                            ansiColor('xterm') {
                                //println "\u001B[31m Triggered by $user so SonarScan has been skipped\u001B[0m";
                            }
                        }
                    }
                }
            }

            stage('Fortify-Scan'){
                steps{
                    dir('src'){
                        script{
                            Map fortifymp = [
                                commitID: gitInfo.GIT_COMMIT,
                                branch: gitInfo.GIT_BRANCH,
                                repourl: gitInfo.GIT_URL,
                                fortifyProjectName: "IPE_MTX99",
                                fortifyVersionName: "IPE_MTX99",
                                //buildType: "maven"
                                buildType: "custom",
                                scanCommand: "mvn -P ${MODULE} clean package -DskipTest -Dmaven.test.skip=true"
                            ]
                            if (user.toString().equals("pdcifjirajnkfid") || user.toString().equals("mastanvalli")){
                                //performFortifyScan(fortifymp)
                                ansiColor('xterm') {
                                   // println "\u001B[31m  Need to Configure HPF-Scan \u001B[0m"
                                }
                            }else{
                                ansiColor('xterm') {
                                    //println fortifymp
                                    //println "\u001B[31m Triggered by $user so HPF-SCAN has been skipped\u001B[0m";
                                }
                            }
                        }
                    }
                }
            }

           /* stage('Running Reports Jtest-Fortify') {
                steps {
                    parallel(
                                "OSS-Scan": {
                                        script{
                                            Map iqmp = [ commitID: gitInfo.GIT_COMMIT,
                                                        branch: gitInfo.GIT_BRANCH,
                                                        repourl: gitInfo.GIT_URL,
                                                        scantarget: "filecopy.zip",
                                                        iqProjectName: "IPE_MTX99",
                                                        organization: "MAS_or_External",
                                                        appCategory: "Hosted",
                                                        mailto: "avinashbabud@dbs.com,mastanvalli@dbs.com"      

                                                    ]
                                                if (user.toString().equals("pdcifjirajnkfid") || user.toString().equals("mastanvalli")){
                                                    performIQScan(iqmp)
                                                }else{
                                                    ansiColor('xterm') {
                                                        println iqmp
                                                        println "\u001B[31m Triggered by $user so IQ Scan has been skipped\u001B[0m";
                                                    }
                                                }
                                        }
                                    },
                                "SonarScan": {
                                    
                                        script{
                                            Map sonarmp = [commitID: gitInfo.GIT_COMMIT,
                                                        branch: gitInfo.GIT_BRANCH,
                                                        repourl: gitInfo.GIT_URL,
                                                        "sonar.projectKey": "IPE_MTX99",
                                                        "sonar.projectName": "IPE_MTX99",
                                                        "sonar.branch.name": gitInfo.GIT_BRANCH,
                                                        "sonar.sources": ".",
                                                        "sonar.java.binaries": ".",
                                                        "sonar.exclusions": "vendor.js,node_modules",
                                                        qualityGateCheck: false
                                                    ]
                                            if (user.toString().equals("pdcifjirajnkfid") || user.toString().equals("mastanvalli")){
                                                performSonarScan(sonarmp) 
                                            }else{
                                                ansiColor('xterm') {
                                                    println "\u001B[31m Triggered by $user so SonarScan has been skipped\u001B[0m";
                                                }
                                            }
                                        }
                                },
                                 "Fortify-Scan": {
                                    dir('src'){
                                        script{
                                            Map fortifymp = [
                                                commitID: gitInfo.GIT_COMMIT,
                                                branch: gitInfo.GIT_BRANCH,
                                                repourl: gitInfo.GIT_URL,
                                                fortifyProjectName: "IPE_MTX99",
                                                fortifyVersionName: "IPE_MTX99",
                                                //buildType: "maven"
                                                buildType: "custom",
                                                scanCommand: "mvn -P ${MODULE} clean package -DskipTest -Dmaven.test.skip=true"
                                            ]
                                            if (user.toString().equals("pdcifjirajnkfid") || user.toString().equals("mastanvalli")){
                                                performFortifyScan(fortifymp)
                                                ansiColor('xterm') {
                                                    println "\u001B[31m  Need to Configure HPF-Scan \u001B[0m"
                                                }
                                            }else{
                                                ansiColor('xterm') {
                                                    println fortifymp
                                                    println "\u001B[31m Triggered by $user so HPF-SCAN has been skipped\u001B[0m";
                                                }
                                            }
                                            
                                        }
                                    }
                                }
                    )
                }
            }*/
        }
    post
    {
        always
        {
            deleteDir()

            script
            {
                def status = currentBuild.currentResult == 'SUCCESS' ? 'Success' : 'Fail'
                def summaryVal = "IPE_MTX99 Module Deployment - "+Release_Version 
                Map jiramap = [
                "projectKey": "IPEM",
                "ENVIRONMENT": "BUILD",
                "status" : status,
                "JIRA_KEY" : "${env.JIRA_KEY}",
                'addComment': summaryVal,
                'APP_VERSION':Release_Version,
                'CommitID':gitInfo.GIT_COMMIT,
                'Nexus Artifact ID':"filecopy",
                'Nexus Group ID':"com.dbs.ibgt",
                'Repo URL': gitInfo.GIT_URL
                ]
                if (user.toString().equals("pdcifjirajnkfid") || user.toString().equals("mastanvalli")){
                    ansiColor('xterm'){
                    updateJiraTicket(jiramap)
                    }
                }else{
                    ansiColor('xterm') {
                        println jiramap
                        println "\u001B[31m Triggered by $user so JIRA Update has been skipped\u001B[0m";
                    }
                }
            }
        }
    }
}

