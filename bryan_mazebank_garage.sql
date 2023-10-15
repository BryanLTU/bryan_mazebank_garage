CREATE TABLE IF NOT EXISTS `bryan_garage_owners` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) NOT NULL,
  PRIMARY KEY (`identifier`),
  KEY `id` (`id`)
);

CREATE TABLE IF NOT EXISTS `bryan_garage_vehicles` (
  `identifier` varchar(50) NOT NULL,
  `plate` varchar(50) NOT NULL,
  `properties` longtext NOT NULL,
  `slot` int(5) NOT NULL DEFAULT 1
);
