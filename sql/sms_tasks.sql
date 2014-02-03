SET NAMES utf8;

DROP TABLE IF EXISTS `sms_tasks`;

CREATE TABLE `sms_tasks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `status` enum('new','running','success','fail','stop') NOT NULL DEFAULT 'stop',
  `log` text,
  `date_start` datetime DEFAULT NULL,
  `date_end` datetime DEFAULT NULL,
  `hash` varchar(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `hash_key` (`hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;