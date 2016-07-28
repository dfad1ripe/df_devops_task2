drop database if exists devops;
create database devops;
grant all privileges on devops.* to 'service_stage'@'localhost';
create table devops.cities(id int not null auto_increment, name varchar(64) not null, population int, primary key(id));
insert into devops.cities(name, population) values('Paris', 10550000);
insert into devops.cities(name, population) values('Dhaka', 6970000);