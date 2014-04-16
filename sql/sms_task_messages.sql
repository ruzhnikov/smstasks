SET NAMES utf8;

DROP TABLE IF EXISTS `sms_task_messages`;

CREATE TABLE `sms_task_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
