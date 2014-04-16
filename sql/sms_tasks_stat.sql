SET NAMES utf8;

DROP TABLE IF EXISTS `sms_tasks_stat`;

CREATE TABLE `sms_tasks_stat` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `task_id` int(11) NOT NULL,
  `date_start` datetime DEFAULT NULL,
  `date_end` datetime DEFAULT NULL,
  `status` enum('success','fail') DEFAULT NULL,
  `log` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
