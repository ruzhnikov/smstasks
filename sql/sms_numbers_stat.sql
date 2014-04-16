SET NAMES utf8;

DROP TABLE IF EXISTS `sms_numbers_stat`;

CREATE TABLE `sms_numbers_stat` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `task_id` int(11) NOT NULL,
  `number` varchar(15) DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  `status` enum('running','success','fail') DEFAULT NULL,
  `uid` int(10) unsigned DEFAULT NULL,
  `log` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
