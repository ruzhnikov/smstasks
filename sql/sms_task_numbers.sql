SET NAMES utf8;

DROP TABLE IF EXISTS `sms_task_numbers`;

CREATE TABLE `sms_task_numbers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `task_id` int(11) NOT NULL,
  `message_id` int(11) NOT NULL,
  `number` varchar(15) NOT NULL,
  `status` enum('new','running','success','fail') NOT NULL DEFAULT 'new',
  `uid` int(10) unsigned NOT NULL,
  `repeat_count` smallint(6) NOT NULL DEFAULT '0',
  `push_id` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `num_uid_task` (`number`,`uid`,`task_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;