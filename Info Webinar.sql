create database info_webinar;
use info_webinar;

create table buat_id(
    nama_id varchar(15),
    value_terakhir int
);
insert into buat_id values
('pengguna', 0),
('webinar', 0),
('komentar', 0);

create table log(
    aktivitas_id varchar(20),
    keterangan varchar(200),
    tanggal_ditambahkan timestamp default current_timestamp
);

create table pengguna(
    id_pengguna varchar(10) default 'Kosong',
    username varchar(25),
    kata_sandi varchar(100),
    primary key (id_pengguna)
);

create table webinar(
    id_webinar varchar(10) default 'Kosong',
    id_pengguna varchar(10),
    nama_webinar varchar(100),
    kategori varchar(20),
    waktu_mulai timestamp,
    waktu_selesai timestamp,
    deadline timestamp,
    link_pendaftaran varchar(70),
    status_webinar varchar(20) default 'Belum Dimulai',
    primary key (id_webinar)
);

create table partisipan_webinar(
    id_pengguna varchar(10),
    id_webinar varchar(10),
    tanggal_daftar timestamp default current_timestamp
);

create table rating_webinar(
    id_webinar varchar(10),
    rating decimal(5, 2)
);

create table komentar(
    id_komentar varchar(10) default 'Kosong',
    id_webinar varchar(10),
    id_pengguna varchar(10),
    komentar varchar(100),
    rating_webinar int, -- Rating Dari 1 Sampai 10
    primary key (id_komentar)
);

-- Relasi Table Webinar
alter table webinar add constraint pengguna_webinar foreign key (id_pengguna) references pengguna (id_pengguna);

-- Relasi Table Partisipan Webinar
alter table partisipan_webinar add constraint partisipan_fk foreign key (id_pengguna) references pengguna (id_pengguna);
alter table partisipan_webinar add constraint webinar_partisipan foreign key (id_webinar) references webinar (id_webinar);

-- Relasi Table Rating Webinar
alter table rating_webinar add constraint rating_fk foreign key (id_webinar) references webinar (id_webinar);

-- Relasi Table Komentar
alter table komentar add constraint webinar_komentar foreign key (id_webinar) references webinar (id_webinar);
alter table komentar add constraint pengguna_komentar foreign key (id_pengguna) references pengguna (id_pengguna);

-- Sebelum Menambahkan Pengguna
DELIMITER //
create trigger sebelum_input_pengguna
before insert on pengguna
for each row
begin
    declare id int;
    select value_terakhir + 1 into id from buat_id where nama_id = 'pengguna';
    set new.id_pengguna = concat('PG', id);
    update buat_id set value_terakhir = id where nama_id = 'pengguna';
end//
DELIMITER ;

-- Setelah Menambahkan Pengguna
DELIMITER //
create trigger setelah_input_pengguna
after insert on pengguna
for each row
begin
    declare ket varchar(200);
    set ket = concat('Selamat ', new.username, ' Menjadi Pengguna Baru');
    insert into log(
        aktivitas_id,
        keterangan
    ) values (
        new.id_pengguna,
        ket
    );
end//
DELIMITER ;

-- Sebelum Menambahkan Webinar
DELIMITER //
create trigger sebelum_input_webinar
before insert on webinar
for each row
begin
    declare id int;
    declare pengguna_tersedia int;
    select count(*) into pengguna_tersedia from pengguna where id_pengguna = new.id_pengguna;
    if pengguna_tersedia < 1 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='pengguna tidak tersedia';
    else
        select value_terakhir + 1 into id from buat_id where nama_id = 'webinar';
        set new.id_webinar = concat('WB', id);
        update buat_id set value_terakhir = id where nama_id = 'webinar';
    end if;
end//
DELIMITER ;

-- Setelah Menambahkan Webinar
DELIMITER //
create trigger setelah_input_webinar
after insert on webinar
for each row
begin
    declare ket varchar(200);
    declare username_var varchar(25);
    
    select username into username_var from pengguna where id_pengguna = new.id_pengguna;
    
    set ket = concat(username_var, ' Baru Saja Membuat Webinar ', new.kategori, ' Dengan Tema ', new.nama_webinar);
    
    insert into log(
        aktivitas_id,
        keterangan
    ) values (
        new.id_webinar,
        ket
    );
end//
DELIMITER ;

-- Sebelum Update Webinar
DELIMITER //
create trigger sebelum_update_webinar
before update on webinar
for each row
begin
    if new.status_webinar != 'Update' then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Update Tidak Valid';
    else
        if new.waktu_mulai <= current_timestamp and current_timestamp < new.waktu_selesai then
            set new.status_webinar = 'Berjalan';
        elseif new.waktu_selesai <= current_timestamp then
            set new.status_webinar = 'Selesai';
        else
            set new.status_webinar = 'Belum Dimulai';
        end if;
    end if;
end//
DELIMITER ;

-- Setelah Update Webinar
DELIMITER //
create trigger setelah_update_webinar
after update on webinar
for each row
begin
    declare status_var varchar(20);
    declare ket varchar(200);
    if new.status_webinar = 'Berjalan' then
        set status_var = 'Berjalan';
    elseif new.status_webinar = 'Selesai' then
        set status_var = 'Selesai';
    else
        set status_var = 'Belum Dimulai';
    end if;
    set ket = concat('Webinar ', new.nama_webinar, ' Berstatus: ', status_var);
    insert into log(
        aktivitas_id,
        keterangan
    ) values (
        new.id_webinar,
        ket
    );
end//
DELIMITER ;

-- Sebelum Daftar Webinar
DELIMITER //
create trigger sebelum_daftar_webinar
before insert on partisipan_webinar
for each row
begin
    declare pengguna_tersedia int;
    declare webinar_tersedia int;
    declare daftar_tersedia int;
    declare webinar_valid int;
    declare deadline_valid int;
    declare waktu_mulai_duplikat int;
    declare waktu_mulai_var timestamp;
    declare pesan_error_duplikat varchar(200);
    declare nama_webinar_var varchar(100);
    
    select count(*) into pengguna_tersedia from pengguna where id_pengguna = new.id_pengguna;
    select count(*) into webinar_tersedia from webinar where id_webinar= new.id_webinar;
    select count(*) into daftar_tersedia from partisipan_webinar where id_webinar = new.id_webinar and id_pengguna = new.id_pengguna;
    select count(*) into webinar_valid from webinar where id_webinar = new.id_webinar and waktu_mulai < current_timestamp;
    select count(*) into deadline_valid from webinar where deadline <= current_timestamp and current_timestamp < waktu_mulai and id_webinar = new.id_webinar;
    if pengguna_tersedia < 1 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='pengguna tidak tersedia';
    elseif webinar_tersedia < 1 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='webinar tidak tersedia';
    elseif daftar_tersedia >0 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='pengguna sudah terdaftar';
    elseif webinar_valid > 0 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Webinar Ini Sudah Tidak Berlaku Lagi';
    elseif deadline_valid > 0 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Webinar Ini Sudah Menutup Pendaftaran';
    else
		select waktu_mulai into waktu_mulai_var from webinar where id_webinar = new.id_webinar;
        select webinar.nama_webinar, count(*) into nama_webinar_var, waktu_mulai_duplikat from webinar join partisipan_webinar on webinar.id_webinar = partisipan_webinar.id_webinar where webinar.waktu_mulai = waktu_mulai_var and webinar.id_webinar != new.id_webinar and webinar.status_webinar = 'Belum Dimulai' and partisipan_webinar.id_pengguna = new.id_pengguna group by webinar.nama_webinar;
        if waktu_mulai_duplikat > 0 then
            set pesan_error_duplikat = concat('Jadwal Webinar Bertabrakan Dengan Webinar ', nama_webinar_var);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = pesan_error_duplikat;
        end if;
    end if;
end//
DELIMITER ;

-- Setelah Daftar Webinar
DELIMITER //
create trigger setelah_daftar_webinar
after insert on partisipan_webinar
for each row
begin
    declare aktivitas_id_var varchar(20);
    declare username_var varchar(25);
    declare nama_webinar_var varchar(100);
    declare ket varchar(200);
    
    select username into username_var from pengguna where id_pengguna = new.id_pengguna;
    select nama_webinar into nama_webinar_var from webinar where id_webinar = new.id_webinar;
    set aktivitas_id_var = concat(new.id_pengguna, ', ', new.id_webinar);
    set ket = concat('Pengguna ', username_var, ' Telah Mendaftar Webinar ', nama_webinar_var);
    insert into log(
        aktivitas_id,
        keterangan
    ) values (
        aktivitas_id_var,
        ket
    );
end//
DELIMITER ;

-- Sebelum Menambahkan Komentar
DELIMITER //
create trigger sebelum_input_komentar
before insert on komentar
for each row
begin
    declare id int;
    declare pengguna_terdaftar int;
    declare waktu_selesai_var timestamp;
    declare status_webinar_var varchar(20);
    select waktu_selesai, status_webinar into waktu_selesai_var, status_webinar_var from webinar where id_webinar = new.id_webinar;
    select count(*) into pengguna_terdaftar from partisipan_webinar where id_pengguna = new.id_pengguna and id_webinar = new.id_webinar;
    if pengguna_terdaftar < 1 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pengguna Tidak Terdaftar Pada Webinar';
    end if;
    if waktu_selesai_var <= current_timestamp and status_webinar_var = 'Selesai' then
        if new.rating_webinar > 10 then
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rating Harus Dari Rentang 1 Sampai 10';
        end if;
        select value_terakhir + 1 into id from buat_id where nama_id = 'komentar';
        set new.id_komentar = concat('KMN', id);
        update buat_id set value_terakhir = id where nama_id = 'komentar';
    else
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tidak Dapat Menambahkan Komentar Ketika Webinar Belum Resmi Berakhir';
    end if;
end//
DELIMITER ;

-- Setelah Menambahkan Komentar
DELIMITER //
create trigger setelah_input_komentar
after insert on komentar
for each row
begin
    declare jumlah_komentar int;
    declare total_rating int;
    declare rating_var decimal(5, 2);
    declare rating_tersedia int;
    declare username_var varchar(25);
    declare nama_webinar_var varchar(100);
    declare ket_rating varchar(200);
    declare ket_komen varchar(200);
    select nama_webinar into nama_webinar_var from webinar where id_webinar = new.id_webinar;
    select count(*) into rating_tersedia from rating_webinar where id_webinar = new.id_webinar;
    select count(*) into jumlah_komentar from komentar where id_webinar = new.id_webinar;
    select sum(rating_webinar) into total_rating from komentar where id_webinar = new.id_webinar;
    set rating_var = total_rating / jumlah_komentar;
    select username into username_var from pengguna where id_pengguna = new.id_pengguna;
    if rating_tersedia > 0 then
        update rating_webinar set rating = rating_var where id_webinar = new.id_webinar;
    else
        insert into rating_webinar values (
            new.id_webinar,
            rating_var
        );
    end if;
    set ket_komen = concat(username_var, ' Memberi Komentar Pada Webinar ', nama_webinar_var, ' Dan Memberikan Rating ', new.rating_webinar);
    set ket_rating = concat('Webinar ', nama_webinar_var, ' Kini Memiliki Rating ', rating_var);
    insert into log(
        aktivitas_id,
        keterangan
    ) values (
        new.id_komentar,
        ket_komen
    ),
    (
        new.id_webinar,
        ket_rating
    );
end//
DELIMITER ;

-- Uji Coba

-- 1 (Blok Dari Sini)
insert into pengguna (username, kata_sandi) values
('Ahmad Nur Huda', 'ahmadnurhuda'),
('Ahmad Nur', 'ahmadnur'),
('Nur Huda', 'nurhuda'),
('Ahmad Huda', 'ahmadhuda'),
('Huda', 'huda'),
('Nur', 'nur');
select * from pengguna;
select * from log;
-- 1 (Sampai Sini)

-- 2 (Blok Dari Sini)
insert into webinar (id_pengguna, nama_webinar, kategori, waktu_mulai, waktu_selesai, deadline, link_pendaftaran) values
('PG1', 'Public Speaking Efektik', 'Soft Skill', '2024-12-11 17:00:00', '2024-12-11 19:00:00', '2024-12-10 21:00:00', 'https://minartis.com/public-speaking-efektif/'),
('PG3', 'Strategi Konten Kreator', 'Soft Skill', '2024-12-15 20:00:00', '2024-12-15 23:00:00', '2024-12-13 20:00:00', 'https://minartis.com/strategi-konten-kreator/'),
('PG4', 'Parenting Islam Mencetak Generasi Quran', 'Bimbingan Konseling', '2024-12-11 17:00:00', '2024-12-11 21:00:00', '2024-12-09 20:00:00', 'https://minartis.com/belajar-teknik-parenting/'),
('PG2', 'Strategi Dapat Kerja', 'Hard Skill', '2024-12-12 18:30:00', '2024-12-12 21:00:00', '2024-12-11 15:00:00', 'https://minartis.com/rahasia-sukses-dapat-kerja/'),
('PG6', 'Pencegahan Kasus Kekerasan Terhadap Anak', 'Bimbingan Konseling', '2024-12-20 14:40:00', '2024-12-20 16:40:00', '2024-12-18 16:40:00', 'https://minartis.com/pencegahan-kasus-kekerasan-terhadap-anak/'),
('PG5', 'Pneumonia Pada Dewasa', 'Farmasi', '2024-12-16 13:50:00', '2024-12-16 16:50:00', '2024-12-15 15:50:00', 'https://minartis.com/infeksi-paru-paru-cegah-dengan-vaksinasi/'),
('PG6', 'Rahasia Memiliki Bisnis Autopilot', 'Bisnis', '2024-12-8 15:07:00', '2024-12-8 15:07:10', '2024-12-8 15:06:50', 'https://minartis.com/rahasia-memiliki-bisnis-autopilot/');
select * from webinar;
select * from log;
-- 2 (Sampai Sini)

-- 3 (Blok Dari Sini)
insert into partisipan_webinar(id_pengguna, id_webinar) values
('PG5', 'WB1'),
('PG2', 'WB1'),
('PG4', 'WB1'),
('PG5', 'WB5'),
('PG3', 'WB4'),
('PG2', 'WB6');

insert into partisipan_webinar(id_pengguna, id_webinar) values
('PG4', 'WB3');
insert into partisipan_webinar(id_pengguna, id_webinar) values
('PG1', 'WB7');
select * from partisipan_webinar;
select * from webinar;
select * from log;
-- 3 (Sampai Sini)

-- 4 (Blok Dari Sini)
update webinar set status_webinar = 'Update';
insert into komentar (id_webinar, id_pengguna, komentar, rating_webinar) values ('WB7', 'PG1', 'Halo icibos', 9);
insert into komentar (id_webinar, id_pengguna, komentar, rating_webinar) values ('WB7', 'PG1', 'Tes icibos', 7);
insert into komentar (id_webinar, id_pengguna, komentar, rating_webinar) values ('WB7', 'PG1', 'Tes icibos', 11);
insert into komentar (id_webinar, id_pengguna, komentar, rating_webinar) values ('WB7', 'PG2', 'Halo icibos', 5);
insert into komentar (id_webinar, id_pengguna, komentar, rating_webinar) values ('WB6', 'PG1', 'Halo icibos', 5);

select * from komentar;
select * from webinar;
select * from rating_webinar;
select * from log;
-- 4 (Sampai Sini)