CREATE DATABASE  IF NOT EXISTS `vdt2025` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `vdt2025`;
-- MySQL dump 10.13  Distrib 8.0.40, for Win64 (x86_64)
--
-- Host: localhost    Database: vdt2025
-- ------------------------------------------------------
-- Server version	8.0.40

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `students`
--

DROP TABLE IF EXISTS `students`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `students` (
  `id` int NOT NULL AUTO_INCREMENT,
  `ho_ten` varchar(100) NOT NULL,
  `ngay_sinh` date NOT NULL,
  `truong` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `students`
--

LOCK TABLES `students` WRITE;
/*!40000 ALTER TABLE `students` DISABLE KEYS */;
INSERT INTO `students` VALUES (1,'Nguyễn Đăng Quân','2004-05-11','Đại học Công nghệ (UET)'),(2,'Trịnh Vinh Tuấn Đạt','2003-10-05','Học viện Công nghệ Bưu chính Viễn thông - Cơ sở phía Bắc'),(3,'Ngô Xuân Hòa','2004-07-27','Học viện Công nghệ Bưu chính Viễn thông - Cơ sở phía Bắc'),(4,'Bùi Đức Hùng','2004-07-31','Đại học Bách Khoa Hà Nội (HUST)'),(5,'Nguyễn Tuấn Anh','2003-01-25','Đại học Bách Khoa Hà Nội (HUST)'),(6,'Lương Nhật Hào','2003-07-09','Đại học Công nghệ (UET)'),(7,'Nguyễn Đức Anh','2003-01-23','Học viện Công nghệ Bưu chính Viễn thông - Cơ sở phía Bắc'),(8,'Đinh Trường Lãm','2001-02-23','Đại học tổng hợp ITMO'),(9,'Nguyễn Đăng Bảo Lâm','2004-08-17','Đại học Bách Khoa Hà Nội (HUST)'),(10,'Phạm Ngọc Hải Dương','2005-03-20','Đại học Công nghệ (UET)'),(11,'Nguyễn Minh Quân','2004-01-05','Đại học Bách Khoa Hà Nội (HUST)'),(12,'Nguyễn Sỹ Tân','2004-07-07','Đại học Công nghệ (UET)'),(13,'Mai Xuân Duy Quang','2003-07-04','Đại học Bách Khoa Hà Nội (HUST)'),(14,'Lê Tấn Phát','2004-12-15','ĐH Mở Tp.HCM'),(15,'Nguyễn Quang Ninh','2004-04-24','Đại học Công nghệ (UET)'),(16,'Nguyễn Trung Vương','2003-10-03','Đại học Bách Khoa - ĐHQG TPHCM (HCMUT)'),(17,'Nguyễn Phước Ngưỡng Long','2005-10-18','Đại học Công nghệ (UET)'),(18,'Nguyễn Văn Dương','2003-10-30','Đại học Công nghệ (UET)'),(19,'Lê Minh Hoàng','2004-05-17','Đại học Khoa học tự nhiên - ĐHQG TPHCM (HCMUS)'),(20,'Nguyễn Đức Thịnh','2001-09-10','Đại học Thủy Lợi'),(21,'Hoàng Minh Thắng','1999-06-09','Đại học tổng hợp ITMO'),(22,'Vũ Đình Ngọc Bảo','2005-01-29','Đại học Khoa học tự nhiên - ĐHQG TPHCM (HCMUS)'),(23,'Nguyễn Hồng Lĩnh','2003-12-08','Đại học Công nghệ (UET)');
/*!40000 ALTER TABLE `students` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user`
--

DROP TABLE IF EXISTS `user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `hashed_password` varchar(255) NOT NULL,
  `role` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user`
--

LOCK TABLES `user` WRITE;
/*!40000 ALTER TABLE `user` DISABLE KEYS */;
INSERT INTO `user` VALUES (1,'xuanhoa','$2b$12$/0JC/jGl2FYJW6oYOB2RwOpJ6oZIQLH8IJ0grUSQWl3DsF/1/tFUG','user'),(2,'admin','$2b$12$ZDlIMay8eahZAf31BT674O3E/RDXs640bPIzoakCg4iuH5WPWca.S','admin');
/*!40000 ALTER TABLE `user` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-06-20  2:54:08
