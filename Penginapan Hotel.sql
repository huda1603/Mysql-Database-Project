CREATE DATABASE PENGINAPAN_HOTEL;
USE PENGINAPAN_HOTEL;

create table buat_id(
    nama_id varchar(10),
    value_terakhir int
);

create table log(
    aktivitas_id varchar(10),
    tanggal_ditambahkan timestamp default current_timestamp,
    keterangan varchar(200)
);

create table kamar(
    id_kamar varchar(10) default 'Kosong',
    nomor int,
    tipe_kamar varchar(20),
    harga_permalam decimal(12, 2) default '0',
    status_ketersediaan varchar(20) default 'Tersedia',
    primary key(id_kamar)
);

create table karyawan(
    id_karyawan varchar(10) default 'Kosong',
    nama varchar(50),
    posisi varchar(20),
    shift_kerja time,
    no_telepon varchar(10),
    email varchar(50),
    primary key(id_karyawan)
);

create table tamu(
    id_tamu varchar(10) default 'Kosong',
    nama varchar(50),
    alamat varchar(100),
    no_telepon varchar(10),
    email varchar(50),
    identifikasi varchar(50),
    kartu_hotel_premium varchar(10) default 'Tidak Ada',
    tanggal_berakhir_kartu timestamp default null,
    primary key(id_tamu)
);

create table pemesanan(
    id_pemesanan varchar(10) default 'Kosong',
    id_tamu varchar(10),
    id_kamar varchar(10),
    id_karyawan varchar(10) default null,
    jumlah_tamu_dewasa int,
    jumlah_tamu_seluruh int,
    tanggal_checkin timestamp default current_timestamp,
    tanggal_checkout timestamp default current_timestamp,
    status_pemesanan varchar(15) default 'Diproses',
    primary key(id_pemesanan)
);

create table pembayaran(
    id_pembayaran varchar(10) default 'Kosong',
    id_pemesanan varchar(10),
    id_karyawan varchar(10),
    tanggal_pembayaran timestamp default null,
    jumlah_pembayaran decimal(12, 2) default '0',
    metode_pembayaran varchar(15) default 'Pilih Metode',
    primary key(id_pembayaran)
);

-- Trigger

-- Sebelum Masukkan (Kamar)
DELIMITER //
create trigger sebelum_input_kamar
before insert on kamar
for each row
begin
    declare id int;
    declare jumlah_kamar int;
    select count(*) into jumlah_kamar from kamar;
    if jumlah_kamar > 50 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Jumlah Kamar Sudah Memenuhi Batas Maksimal 50';
    else
        select value_terakhir + 1 into id from buat_id where nama_id = 'kamar';
        set new.id_kamar = concat('Kamar', id);
        update buat_id set value_terakhir = id where nama_id = 'kamar';
        
        if new.tipe_kamar = 'Single Room' then
            set new.harga_permalam = 90000.00;
        elseif new.tipe_kamar = 'Double Room' then
            set new.harga_permalam = 150000.00;
        elseif new.tipe_kamar = 'Twin Room' then
            set new.harga_permalam = 120000.00;
        elseif new.tipe_kamar = 'Family Room' then
            set new.harga_permalam = 250000.00;
        end if;
    end if;
end//
DELIMITER ;

-- Setelah Masukkan (Kamar)
DELIMITER //
create trigger setelah_input_kamar
after insert on kamar
for each row
begin
    declare ket varchar(200);
    set ket = concat('Kamar Nomor ', new.nomor, ' Bertipe ', new.tipe_kamar, ' Berhasil Ditambahkan');
    
    insert into log(
		aktivitas_id,
        keterangan
    ) values (
        new.id_kamar,
        ket
    );
end//
DELIMITER ;

-- Sebelum Masukkan (Karyawan)
DELIMITER //
create trigger sebelum_input_karyawan
before insert on karyawan
for each row
begin
    declare id int;
    declare jumlah_karyawan int;
    
    select count(*) into jumlah_karyawan from karyawan where posisi=new.posisi;
    
    if jumlah_karyawan > 15 and new.posisi='Staff' then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Jumlah Staff Sudah Memenuhi Batas Maksimal 15';
    elseif jumlah_karyawan > 5 and new.posisi='Receptionist' then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Jumlah Resepsionis Sudah Memenuhi Batas Maksimal 5';
    elseif jumlah_karyawan > 10 and new.posisi='Housekeeper' then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Jumlah Housekeeper Sudah Memenuhi Batas Maksimal 10';
    else
        select value_terakhir + 1 into id from buat_id where nama_id = 'karyawan';
        set new.id_karyawan = concat('Karyawan', id);
        update buat_id set value_terakhir = id where nama_id = 'karyawan';
    end if;
end//
DELIMITER ;

-- Setelah Masukkan (Karyawan)
DELIMITER //
create trigger setelah_input_karyawan
after insert on karyawan
for each row
begin
    declare ket varchar(200);
    set ket = concat(new.nama, ' Resmi Menjadi Karyawan Baru Pada Posisi ', new.posisi);
    insert into log(
        aktivitas_id,
        keterangan
    ) values (
        new.id_karyawan,
        ket
    );
end//
DELIMITER ;

-- Sebelum Masukkan (Tamu)
DELIMITER //
create trigger sebelum_input_tamu
before insert on tamu
for each row
begin
    declare id int;
    select value_terakhir + 1 into id from buat_id where nama_id = 'tamu';
    set new.id_tamu = concat('TM', id);
    update buat_id set value_terakhir = id where nama_id = 'tamu';
end//
DELIMITER ;

-- Sebelum Masukkan (Pesanan)
DELIMITER //
create trigger sebelum_input_pesanan
before insert on pemesanan
for each row
begin
    declare id int;
    declare kamar_dipesan int;
    declare tamu_pemesan int;
    declare tamu_sudah_memesan int;
    declare nomor_kamar int;
    declare tipe_kamar_var varchar(20);
    
    select count(*) into kamar_dipesan from pemesanan where id_kamar = new.id_kamar and status_pemesanan = new.status_pemesanan;
    select count(*) into tamu_pemesan from pemesanan where id_tamu = new.id_tamu and status_pemesanan = new.status_pemesanan;
    select count(*) into tamu_sudah_memesan from pemesanan where id_tamu = new.id_tamu and id_kamar = new.id_kamar and status_pemesanan = new.status_pemesanan;
    
    if tamu_sudah_memesan > 0 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Tamu Sudah Memesan Kamar Ini';
    elseif kamar_dipesan > 0 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Kamar Ini Sudah Di Pesan Oleh Tamu Lain Sebelumnya';
    elseif tamu_pemesan > 0 then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Tamu Tidak Dapat Memesan Lebih Dari 1 Kamar';
    else
        select nomor, tipe_kamar into nomor_kamar, tipe_kamar_var from kamar where id_kamar = new.id_kamar;
        if tipe_kamar_var = 'Single Room' and new.jumlah_tamu_dewasa > 1 then
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Kamar Single Room Tidak Dapat Menampung Lebih Dari 1 Tamu Dewasa';
        elseif tipe_kamar_var = 'Double Room' and new.jumlah_tamu_dewasa > 2 then
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Kamar Double Room Tidak Dapat Menampung Lebih Dari 2 Tamu Dewasa';
        elseif tipe_kamar_var = 'Twin Room' and new.jumlah_tamu_dewasa > 2 then
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Kamar Twin Room Tidak Dapat Menampung Lebih Dari 2 Tamu Dewasa';
        end if;
        if nomor_kamar <= 10 then
            set new.id_karyawan = 'Karyawan2';
        elseif nomor_kamar <= 20 then
            set new.id_karyawan = 'Karyawan3';
        elseif nomor_kamar <= 30 then
            set new.id_karyawan = 'Karyawan4';
        end if;
        select value_terakhir + 1 into id from buat_id where nama_id = 'pemesanan';
        set new.id_pemesanan = concat('PMSN', id);
        update buat_id set value_terakhir = id where nama_id = 'pemesanan';
        update kamar set status_ketersediaan = 'Dihuni' where id_kamar = new.id_kamar;
    end if;
end//
DELIMITER ;

-- Setelah Masukkan (Pesanan)
DELIMITER //
create trigger setelah_input_pesanan
after insert on pemesanan
for each row
begin
    declare nomor_kamar int;
    declare ket varchar(200);
    declare nama_tamu varchar(50);
    declare tipe_kamar_var varchar(20);
    
    select nama into nama_tamu from tamu where id_tamu = new.id_tamu;
    select nomor, tipe_kamar into nomor_kamar, tipe_kamar_var from kamar where id_kamar = new.id_kamar;
    
    set ket = concat('Tamu ', nama_tamu, ' Telah CheckIn Kamar ', tipe_kamar_var, ', Pada Kamar Nomor ', nomor_kamar);
    insert into log(
		aktivitas_id,
        keterangan
    ) values (
        new.id_pemesanan,
        ket
    );
end//
DELIMITER ;

-- Sebelum Update (Pesanan)
DELIMITER //
create trigger sebelum_update_pesanan
before update on pemesanan
for each row
begin
    if new.tanggal_checkout = old.tanggal_checkout and new.status_pemesanan = old.status_pemesanan then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Update Tidak Valid';
    end if;
end//
DELIMITER ;

-- Setelah Update (Pesanan)
DELIMITER //
create trigger setelah_update_pesanan
after update on pemesanan
for each row
begin
    declare id int;
    declare total_malam int;
    declare nomor_kamar int;
    declare history_tamu int;
    declare tanggal_berakhir_kartu_var timestamp;
    declare harga_permalam_var decimal(12, 2);
    declare jumlah_pembayaran_var decimal(12, 2);
    declare pembayaran_id varchar(10);
    declare kartu_hotel_var varchar(10);
    declare tipe_kamar_var varchar(20);
    declare nama_tamu varchar(50);
    declare ket_checkout varchar(200);
    declare ket_pembayaran varchar(200);
    declare ket_kamar varchar(200);
    declare ket_tamu varchar(200);
    
    if new.tanggal_checkout != old.tanggal_checkout then
		select nama, kartu_hotel_premium, tanggal_berakhir_kartu into nama_tamu, kartu_hotel_var, tanggal_berakhir_kartu_var from tamu where id_tamu = new.id_tamu;
        
        select value_terakhir + 1 into id from buat_id where nama_id = 'pembayaran';
        set pembayaran_id = concat('PAY', id);
        update buat_id set value_terakhir = id where nama_id = 'pembayaran';
        
        select nomor, tipe_kamar, harga_permalam into nomor_kamar, tipe_kamar_var, harga_permalam_var from kamar where id_kamar = new.id_kamar;
        set total_malam = datediff(new.tanggal_checkout, new.tanggal_checkin);
        
        if kartu_hotel_var = 'Ada' and tanggal_berakhir_kartu_var > current_timestamp then
            set jumlah_pembayaran_var = ((harga_permalam_var * total_malam)*new.jumlah_tamu_dewasa) * (95/100);
        else
            set jumlah_pembayaran_var = (harga_permalam_var * total_malam)*new.jumlah_tamu_dewasa;
        end if;
        
        set ket_checkout = concat('Tamu ', nama_tamu, ' Melakukan Telah Melakukan Checkout Kamar ', tipe_kamar_var, ', Pada Kamar Nomor ', nomor_kamar, ', Tinggal Menunggu Pembayaran');
            
        insert into pembayaran(
            id_pembayaran,
            id_pemesanan,
            id_karyawan,
            jumlah_pembayaran
        ) values (
            pembayaran_id,
            new.id_pemesanan,
            new.id_karyawan,
            jumlah_pembayaran_var
        );
        insert into log(
			aktivitas_id,
            keterangan
        ) values (
			new.id_pemesanan,
            ket_checkout
        );
    elseif new.status_pemesanan != old.status_pemesanan then
        select count(*) into history_tamu from pemesanan where id_tamu = new.id_tamu and status_pemesanan = new.status_pemesanan;
        select nama into nama_tamu from tamu where id_tamu = new.id_tamu;
        select nomor into nomor_kamar from kamar where id_kamar = new.id_kamar;
        update kamar set status_ketersediaan = 'Tersedia' where id_kamar = new.id_kamar;
        set ket_pembayaran = concat('Tamu ', nama_tamu, ' Yang Sudah Checkout Kini Telah Membayar Pada Kamar Nomor ', nomor_kamar);
        set ket_kamar = concat('Kini Kamar Nomor ', nomor_kamar, ' Sudah Tersedia Kembali');
        insert into log(
			aktivitas_id,
            keterangan
        ) values (
			new.id_pemesanan,
            ket_pembayaran
        ),
        (
			new.id_kamar,
            ket_kamar
        );
        if history_tamu = 3 then
            set ket_tamu = concat('Tamu ', nama_tamu, ' Resmi Mendapatkan Kartu Premium Hotel');
            update tamu set kartu_hotel_premium = 'Ada', tanggal_berakhir_kartu = date_add(current_timestamp, interval 30 day) where id_tamu = new.id_tamu;
            insert into log(
                aktivitas_id,
                keterangan
            ) values (
                new.id_tamu,
                ket_tamu
            );
        elseif history_tamu > 3 then
            update tamu set tanggal_berakhir_kartu = date_add(tanggal_berakhir_kartu, interval 21 day) where id_tamu = new.id_tamu;
        end if;
    end if;
end//
DELIMITER ;

-- Sebelum Update (Pembayaran)
DELIMITER //
create trigger sebelum_update_pembayaran
before update on pembayaran
for each row
begin
    if new.metode_pembayaran = old.metode_pembayaran then
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT ='Update Tidak Valid';
	else
		set new.tanggal_pembayaran = current_timestamp;
    end if;
end//
DELIMITER ;

-- Setelah Update (Pembayaran)
DELIMITER //
create trigger setelah_update_pembayaran
after update on pembayaran
for each row
begin
    if new.metode_pembayaran != old.metode_pembayaran then
        update pemesanan set status_pemesanan = 'Dibayar' where id_pemesanan = new.id_pemesanan;
    end if;
end//
DELIMITER ;

-- Uji Coba
-- 1 (Blok Dari Sini)
insert into buat_id values
('kamar', 0),
('karyawan', 0),
('tamu', 0),
('pemesanan', 0),
('pembayaran', 0);

insert into kamar (nomor, tipe_kamar, harga_permalam) values
(1, 'Single Room', 90000.00),
(2, 'Single Room', 90000.00),
(3, 'Single Room', 90000.00),
(4, 'Single Room', 90000.00),
(5, 'Double Room', 150000.00),
(6, 'Double Room', 150000.00),
(7, 'Double Room', 150000.00),
(8, 'Double Room', 150000.00),
(9, 'Twin Room', 120000.00),
(10, 'Family Room', 250000.00),
(11, 'Single Room', 90000.00),
(12, 'Single Room', 90000.00),
(13, 'Single Room', 90000.00),
(14, 'Single Room', 90000.00),
(15, 'Double Room', 150000.00),
(16, 'Double Room', 150000.00),
(17, 'Double Room', 150000.00),
(18, 'Double Room', 150000.00),
(19, 'Twin Room', 120000.00),
(20, 'Family Room', 250000.00),
(21, 'Single Room', 90000.00),
(22, 'Single Room', 90000.00),
(23, 'Single Room', 90000.00),
(24, 'Single Room', 90000.00),
(25, 'Double Room', 150000.00),
(26, 'Double Room', 150000.00),
(27, 'Double Room', 150000.00),
(28, 'Double Room', 150000.00),
(29, 'Twin Room', 120000.00),
(30, 'Family Room', 250000.00);

insert into karyawan (nama, posisi, shift_kerja, no_telepon, email) values
('Ahmad Nur Huda', 'Staff', '08:00:00', '0812345678', 'ahmad.nurhuda@gmail.com'),
('Nur Huda', 'Receptionist', '11:00:00', '0823456789', 'nur.huda@gmail.com'),
('Huda', 'Receptionist', '14:00:00', '0834567890', 'huda@gmail.com'),
('Ahmad Nur', 'Receptionist', '07:00:00', '0845678901', 'ahmad.nur@gmail.com'),
('Nur', 'Housekeeping', '16:00:00', '0856789012', 'nur@gmail.com');

insert into tamu (nama, alamat, no_telepon, email, identifikasi) values
('Rina', 'Jl. Merdeka No.1, Samarinda', '0812345678', 'rina@gmail.com', 'KTP123456789'),
('Budi', 'Jl. Pahlawan No.2, Samarinda', '0823456789', 'budi@gmail.com', 'KTP987654321'),
('Sari', 'Jl. Sudirman No.3, Samarinda', '0834567890', 'sari@gmail.com', 'SIM123456789'),
('Dedi', 'Jl. Diponegoro No.4, Samarinda', '0845678901', 'dedi@gmail.com', 'PAS123456789'),
('Eka', 'Jl. Ahmad Yani No.5, Samarinda', '0856789012', 'eka@gmail.com', 'KTP112233445'),
('Fina', 'Jl. Hasanuddin No.6, Samarinda', '0867890123', 'fina@gmail.com', 'SIM998877665'),
('Gani', 'Jl. Gajah Mada No.7, Samarinda', '0878901234', 'gani@gmail.com', 'PAS556677889'),
('Hana', 'Jl. Pemuda No.8, Samarinda', '0889012345', 'hana@gmail.com', 'KTP443322110'),
('Iwan', 'Jl. Sisingamangaraja No.9, Samarinda', '0890123456', 'iwan@gmail.com', 'SIM667788990'),
('Joko', 'Jl. Thamrin No.10, Samarinda', '0801234567', 'joko@gmail.com', 'PAS445566778');

-- Tabel Kamar
select * from kamar;

-- Tabel Karyawan
select * from karyawan;

-- Tabel Tamu
select * from tamu;

-- Tabel Log
select * from log;
-- 1 (Sampai Sini)

-- 2 (Blok Dari Sini)
insert into pemesanan(
    id_tamu,
    id_kamar,
    jumlah_tamu_dewasa,
    jumlah_tamu_seluruh
) values
('TM4', 'Kamar3', 1, 2),
('TM1', 'Kamar10', 5, 5),
('TM7', 'Kamar8', 2, 2),
('TM9', 'Kamar29', 2, 3);

insert into pemesanan(
    id_tamu,
    id_kamar,
    jumlah_tamu_dewasa,
    jumlah_tamu_seluruh
) values
('TM2', 'Kamar17', 3, 4);

insert into pemesanan(
    id_tamu,
    id_kamar,
    jumlah_tamu_dewasa,
    jumlah_tamu_seluruh
) values
('TM6', 'Kamar29', 2, 3);

insert into pemesanan(
    id_tamu,
    id_kamar,
    jumlah_tamu_dewasa,
    jumlah_tamu_seluruh
) values
('TM9', 'Kamar23', 1, 3);

-- Tabel Pemesanan
select * from pemesanan;

-- Tabel Kamar
select * from kamar;

-- Tabel Log
select * from log;
-- 2 (Sampai Sini)

-- 3 (Blok Dari Sini)
update pemesanan set tanggal_checkout = date_add(tanggal_checkout, interval 3 day) where id_pemesanan = 'PMSN2';
update pemesanan set tanggal_checkout = date_add(tanggal_checkout, interval 7 day) where id_pemesanan = 'PMSN3';

-- Tabel Pemesanan
select * from pemesanan;

-- Tabel Pembayaran
select * from pembayaran;

-- Tabel Log
select * from log;
-- 3 (Sampai Sini)

-- 4 (Blok Dari Sini)
update pembayaran set metode_pembayaran = 'Gopay' where id_pembayaran = 'PAY2';

-- Tabel Pemesanan
select * from pembayaran;

-- Tabel Pembayaran
select * from pemesanan;

-- Tabel Kamar
select * from kamar;

-- Tabel Log
select * from log;
-- 4 (Sampai Sini)

insert into pemesanan(
    id_tamu,
    id_kamar,
    jumlah_tamu_dewasa,
    jumlah_tamu_seluruh
) values
('TM7', 'Kamar8', 2, 2);
update pemesanan set tanggal_checkout = date_add(tanggal_checkout, interval 7 day) where id_pemesanan = 'PMSN5';
update pembayaran set metode_pembayaran = 'Gopay' where id_pembayaran = 'PAY3';

select * from buat_id;
select * from kamar;
select * from karyawan;
select * from log;
select * from pembayaran;
select * from pemesanan;
select * from tamu;

insert into pemesanan(
    id_tamu,
    id_kamar,
    jumlah_tamu_dewasa,
    jumlah_tamu_seluruh
) values
('TM7', 'Kamar8', 2, 2);
update pemesanan set tanggal_checkout = date_add(tanggal_checkout, interval 7 day) where id_pemesanan = 'PMSN6';
update pembayaran set metode_pembayaran = 'Gopay' where id_pembayaran = 'PAY4';

select * from buat_id;
select * from kamar;
select * from karyawan;
select * from log;
select * from pembayaran;
select * from pemesanan;
select * from tamu;

insert into pemesanan(
    id_tamu,
    id_kamar,
    jumlah_tamu_dewasa,
    jumlah_tamu_seluruh
) values
('TM7', 'Kamar8', 2, 2);
update pemesanan set tanggal_checkout = date_add(tanggal_checkout, interval 7 day) where id_pemesanan = 'PMSN7';
update pembayaran set metode_pembayaran = 'OVO' where id_pembayaran = 'PAY1';

select * from log;
select * from pembayaran;
select * from pemesanan;

-- Relasi

-- Pemesanan
alter table pemesanan add constraint tamu_pemesanan foreign key(id_tamu) references tamu (id_tamu);
alter table pemesanan add constraint kamar_pemesanan foreign key(id_kamar) references kamar (id_kamar);
alter table pemesanan add constraint karyawan_pemesanan foreign key(id_karyawan) references karyawan (id_karyawan);

-- Pembayaran
alter table pembayaran add constraint pemesanan_pembayaran foreign key(id_pemesanan) references pembayaran (id_pemesanan);
alter table pembayaran add constraint karyawan_pemesanan foreign key(id_karyawan) references karyawan (id_karyawan);