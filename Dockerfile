#	Jenkins
#	=========================
#	## Description:
#
#	Dockerfile for running
# 	Jenkins on top of Tomcat (with
# 	within a docker container plus some docker tools pre-installed.
#
#	## References
#
#	- [Jenkins offical docker image](https://github.com/jenkinsci/docker)
#	- [Tomcat official docker image](https://github.com/docker-library/tomcat/)
#


FROM ubuntu:14.04
MAINTAINER jonathan.rosado@hpe.com ricardo.quintana@hpe.com giovanni.matos@hpe.com

# Version for jenkins
# Update center for jenkins
# Versions for tomcat
# Tomcat home
ENV JENKINS_VERSION=1.609.3 \
	JENKINS_UC=https://updates.jenkins-ci.org \
	TOMCAT_MAJOR_VERSION=8 \
	TOMCAT_MINOR_VERSION=8.0.27 \
	CATALINA_HOME=/tomcat \
        JAVA_HOME='/usr/lib/jvm/java-7-openjdk-amd64'

# Install the supervisor process management tool
# Install the necessary packages to download and install Tomcat and Jenkins
# Clean up packages
# TODO: openjdk-7-jre endpoints seem to be unreliable. apt-get fails to get packages, causing image build to fail.
RUN apt-get update && apt-get install -y git \
    wget \
    curl \
    supervisor \
    openjdk-7-jre \
    fastjar \
    ca-certificates \
    xmlstarlet \
    python-lxml \
    sendmail

RUN wget -q https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_MINOR_VERSION}/bin/apache-tomcat-${TOMCAT_MINOR_VERSION}.tar.gz && \
    wget -qO- https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_MINOR_VERSION}/bin/apache-tomcat-${TOMCAT_MINOR_VERSION}.tar.gz.md5 | md5sum -c - && \
    curl --silent --show-error --retry 5 https://bootstrap.pypa.io/get-pip.py | python2.7 && \
    pip install pyyaml && \
    tar zxf apache-tomcat-*.tar.gz && \
    rm apache-tomcat-*.tar.gz && \
    mv apache-tomcat* tomcat && \
    rm -rf /tomcat/webapps/* && \
    curl -L http://mirrors.jenkins-ci.org/war-stable/$JENKINS_VERSION/jenkins.war -o /tomcat/webapps/ROOT.war && \
    mkdir /tomcat/webapps/ROOT && cd /tomcat/webapps/ROOT && jar -xvf '/tomcat/webapps/ROOT.war' && cd / && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /tomcat/webapps/ROOT/ref/init.groovy.d 

# Add script for running Tomcat
ADD run-tomcat.sh /run.sh


# General YAML parser
ADD configparser.py /configparser.py

# Job migration tools
ADD xml2jobDSL.py /xml2jobDSL.py
ADD xml2yaml.py /xml2yaml.py

# Set the home folder for jenkins
ENV JENKINS_HOME /var/jenkins_home


# Add jenkins user
RUN useradd -d "$JENKINS_HOME" -u 1000 -m -s /bin/bash jenkins


# Add default config.xml
ADD config.xml /config.xml


# Add init file for setting the agent port for jnlp
ADD init.groovy /tomcat/webapps/ROOT/ref/init.groovy.d/tcp-slave-angent-port.groovy


# Add script for adding Jenkins plugins via text file
ADD download-plugins.sh /usr/local/bin/plugins.sh


# Add the text file containing the necessary plugins to be installed
ADD default_jenkins_plugins.txt /usr/share/jenkins/plugins.txt


# Execute the plugins.sh script against plugins.txt to install the necessary plugins
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt && > /usr/share/jenkins/plugins.txt


ADD start_sendmail.sh /start_sendmail.sh

# Add the default supervisor conf
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# Add the job (seed job) that will build all the groovy defined jobs to the container
ADD groovy-dsl-job /var/tmp/groovy-dsl-job


# Add the script that will trigger the seed job
ADD build-groovy-jobs.sh /build-groovy-jobs.sh


# Jenkins CLI tool
ADD jenkins-cli.jar /jenkins-cli.jar


# Script that dispatches the CLI commands to Jenkins
ADD execute-jenkins-cli-commands.sh /execute-jenkins-cli-commands.sh


# XML templates
ADD user-template.xml /user-template.xml


# Script for PW encryption
ADD pwencrypt /usr/bin/pwencrypt


# Port 50000 will be used by jenkins slave
# Port 8080 will be used for the Jenkins web interface
EXPOSE 8080 50000

# install docker 1.6.2
# install docker-compose 1.3.3
RUN wget -qO- https://get.docker.com/ubuntu/ | sed -r 's/^apt-get install -y lxc-docker$/apt-get install -y lxc-docker-1.6.2/g' | sh && \
    curl -L https://github.com/docker/compose/releases/download/1.3.3/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose


# Run Tomcat, plugins.sh (to install the plugins)
CMD ["/usr/bin/supervisord"]
