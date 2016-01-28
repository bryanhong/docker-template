#docker-template

Generate boilerplate scripts for jumpstarting Docker container development

###Requirements / Dependencies

* Docker 1.6 or higher, we are using the Docker syslog driver in this container and this feature made its debut in 1.6

###Commands and variables

* ```generate_ubuntu.sh```: Generate build/run/push scripts and a basic Dockerfile for Ubuntu-based container

###Usage

If you plan on tracking your container development in a version control system, create a repository first and then fetch generate_ubuntu.sh (might add more distros in the future..) to the root of your repository:

```
cd /path/to/your/repo
wget https://raw.githubusercontent.com/bryanhong/docker-template/master/generate_ubuntu.sh
chmod 755 generate_ubuntu.sh
```

####Configure and run generate_ubuntu.sh

1. There are 4 basic variables at the top of ```generate_ubuntu.sh```, change those to suit your needs, save your changes.
2. If there is a README.md file in your repository that is essentially blank, delete it, ```generate_ubuntu.sh``` will create one for you that has the basics to get you started in documenting your container.
3. Run ```generate_ubuntu.sh```
4. You should have a directory structure that looks like this:

```
.
├── assets
│   └── startup.sh
├── build.sh
├── Dockerfile
├── generate_ubuntu.sh
├── push.sh
├── README.md
├── run.sh
├── shell.sh
└── vars
```

####On your own

At this point you can modify things to suit your needs, supervisor is included in the Dockerfile so you can build this image, run a container based on that image, and get a shell on it to try things out. 

####Supervisor

Here's an example supervisor config file if you wanted to run apache:

supervisord.apache2.conf

```
[program:apache2]
command=/bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -c 'ErrorLog /dev/stdout' -DFOREGROUND"
redirect_stderr=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
```

You'd need something like this in your Dockerfile too:

```
RUN apt-get -y install apache2
ADD assets/supervisord.apache2.conf /etc/supervisor/conf.d/apache2.conf
```

####Build the image

1. Run ```./build.sh```

####Start the container

1. If you need to expose ports on the Docker host, you'll need to make changes to ```run.sh``` first, examples are provided.
2. Run ```./run.sh```

####Push image to the repository

If you're happy with your container and ready to share with others, push your image up to the local Docker repository and check in any other changes you've made in this Git repository so the image can be easily changed or rebuilt in the future.

1. Run ```./push.sh```

> NOTE: If your image will be used FROM other containers you might want to use ```./push.sh flatten``` to consolidate the AUFS layers into a single layer. Keep in mind, you may lose Dockerfile attributes when your image is flattened.
