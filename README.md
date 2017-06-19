==========

### What it is

This is a Shibbolized(?) docker version of Request Tracker (henceforth known as RT) meaning
that all user authentication is managed by Shibboleth and RT uses the REMOTE_USER headers to
setup new users. Please keep in mind that RT will automatically create users that reach this
installation so, if you cannot filter users with Shibboleth; use with caution.

### HowTo 

First of all you need to retrieve and build the first image using the Dockerfile in this repo.
You will also have some kind of certificates setup on the host in /etc/ssl and also a directory
to store the database (for us this'd be /docker/var/lib/postgresql/data on the host). Besides
these pre-install-issues here's a list of steps to go through...

* Install docker and git (if you havent already)  
* Clone this repository  
``` git clone https://github.com/SUNET/docker-rt-swamid ```  
* Build a local image that you can use with docker run (or as we do, docker-compose)  
``` docker build -t rt-swamid . ```  
* With rt-swamid built, create a docker-compose.yml file (like the following example):  
~~~~
---
version: '2'
services:

   postgres:
     image: 'postgres:9.5.0'
     volumes:
       - /docker/var/lib/postgresql/data:/var/lib/postgresql/data
     environment:
       - "POSTGRES_PASSWORD=password"
       - "POSTGRES_DB=postgres"
       - "POSTGRES_USER=postgres"
     container_name: postgres
     expose:
       - 5432       

   rt-swamid:
     image: 'rt-swamid'
     environment:
       - "SP_HOSTNAME=rt.example.com"
       - "RT_HOSTNAME=rt.example.com"
       - "RT_OWNER=rt@example.com"
       - "RT_Q1=rt"
       - "RT_Q2=bugs"
     volumes:
       - /etc/ssl:/etc/ssl
     expose:
       - 443
       - 80
       - 25
     ports:
       - '25:25'
       - '443:443'
       - '80:80'
     container_name: rt-swamid
     depends_on:
       - postgres
     links:
       - postgres
~~~~
(ps. You need to edit the environment, especially within "rt-swamid", to suit your needs. ds)  
* Start it all using your (edited!) docker-compose.yml similar to the example above:  
``` docker-compose up ```  
* When everything's up go into the "rt-swamid"-container to initialize your chosen database with RT's schemas  
``` docker exec -it rt-swamid bash ```  
``` cd /tmp/rt/rt-* ```  
``` make initialize-database ```  
(ps. The make above needs the password supplied for the db in the docker-compose.yml. If it fails, which it often does,
     please have a look at the documentation in the README in the directory you're in. Or run it a few times more, which
     worked for me. ;) With the volume for the database you only need to complete this schema-db-setup once. ds.)  
* After these steps you probably want to change the default password for the database and also supply a better password
  for the RT root user before you start editing/changing other stuff. Here are steps to fix this (from inside rt-swamid):  
``` docker exec -it rt-swamid bash ```  
``` perl -I/opt/rt4/local/lib -I/opt/rt4/lib -MRT -MRT::User -e'RT::LoadConfig();RT::Init(); my $u = RT::User->new($RT::SystemUser); $u->Load("root"); $u->SetPassword("GOOD_PASSWORD_GOES_HERE")' ```    
* After all this you need to connect to SWAMID with your new Shibbolized(!) SP, go here to read how to proceed with this:  
  (https://www.sunet.se/swamid/policy/)   

