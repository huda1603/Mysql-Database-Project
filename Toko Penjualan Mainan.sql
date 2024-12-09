CREATE DATABASE TOKO_PENJUALAN_MAINAN;
USE TOKO_PENJUALAN_MAINAN;

CREATE TABLE buat_id(
    nama_id varchar(15),
    value_terakhir int
);
insert into buat_id values
('pelanggan', 0),
('order', 0),
('mainan', 0);

CREATE TABLE rak_kapasitas_mainan(
    id_rak varchar(10),
    kapasitas int,
    primary key(id_rak)
);
insert into rak_kapasitas_mainan values
('RAK1', 150),
('RAK2', 150),
('RAK3', 150);

CREATE TABLE mainan( -- Trigger
    id_mainan varchar(10) default 'Kosong',
    id_rak varchar(10),
    nama_mainan varchar(50),
    kategori varchar(15),
    kondisi varchar(20) default 'Baru',
    harga_satuan decimal(12, 2),
    stok int,
    primary key (id_mainan)
);

CREATE TABLE metode_pembayaran(
    id_metode varchar(10),
    metode varchar(20),
    primary key(id_metode)
);
insert into metode_pembayaran values
('MTD1', 'GOPAY'),
('MTD2', 'ShopeePay'),
('MTD3', 'OVO'),
('MTD4', 'Mobile M-Banking'),
('MTD5', 'ATM');

CREATE TABLE kartu_pelanggan( -- Otomatis
    id_pelanggan varchar(10) default 'Kosong',
    nama_pelanggan varchar(20),
    tipe_kartu varchar(15) default 'Kosong',
    tanggal_berakhir_kartu timestamp default current_timestamp,
    primary key (id_pelanggan)
);

CREATE TABLE log( -- Otomatis, Trigger
    aktivitas_id varchar(10),
    tanggal_ditambahkan timestamp default current_timestamp,
    keterangan varchar(100),
    aktivitas_yang_berkaitan varchar(20)
);

CREATE TABLE order_mainan( -- Trigger
    id_order varchar(10) default 'Kosong',
    id_mainan varchar(10),
    nama_pelanggan varchar(20),
    kuantitas int,
    total_harga decimal(12, 2) default '0',
    status_transaksi varchar(15) default 'Belum Dibayar',
    primary key (id_order)
);

CREATE TABLE bayar_order_mainan( -- Otomatis, Trigger
    id_order varchar(10),
    id_metode varchar(10) default 'Metode'
);

DELIMITER //
create trigger sebelum_order_mainan
before insert on order_mainan
for each row
begin
    declare id int;
    declare stok_var int;
    declare jumlah_penerima_kartu int;
    declare harga_satuan_var decimal(12, 2);
    declare tipe_kartu_var varchar(15);
    declare pesan_error varchar(100);
    declare tanggal_berakhir_var timestamp;
    
    select harga_satuan, stok into harga_satuan_var, stok_var from mainan where id_mainan = new.id_mainan;
    
    if new.kuantitas > stok_var then
		set pesan_error = concat('Kuantitas Melebihi Stok Mainan, Stok Mainan Saat ini: ', stok_var);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = pesan_error;
    elseif new.kuantitas = 0 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Kuantitas Kosong';
    else   
        -- id_order
        select value_terakhir+1 into id from buat_id where nama_id = 'order';    
        set new.id_order = concat('ORD', id);
        update buat_id set value_terakhir = id where nama_id = 'order';
        
        select count(*) into jumlah_penerima_kartu from kartu_pelanggan where nama_pelanggan = new.nama_pelanggan;
        select tanggal_berakhir_kartu into tanggal_berakhir_var from kartu_pelanggan where nama_pelanggan = new.nama_pelanggan;
        
        if jumlah_penerima_kartu > 0 then
            select tipe_kartu into tipe_kartu_var from kartu_pelanggan where nama_pelanggan = new.nama_pelanggan;
            if tipe_kartu_var = 'Gold' and current_timestamp < tanggal_berakhir_var then
                set new.total_harga = (new.kuantitas * harga_satuan_var) * (91/100);
            elseif tipe_kartu_var = 'Platinum' and current_timestamp < tanggal_berakhir_var then
                set new.total_harga = (new.kuantitas * harga_satuan_var) * (94/100);
            elseif tipe_kartu_var = 'Bronze' and current_timestamp < tanggal_berakhir_var then
                set new.total_harga = (new.kuantitas * harga_satuan_var) * (97/100);
			else
			    set new.total_harga = new.kuantitas * harga_satuan_var;
			end if;
        else
            set new.total_harga = new.kuantitas * harga_satuan_var;
		end if;
    end if;
    
    insert into bayar_order_mainan(
        id_order
    ) values (
        new.id_order
    );
end//
DELIMITER ;

DELIMITER //
create trigger setelah_order_mainan
after insert on order_mainan
for each row
begin
    declare ket varchar(100);
    
    set ket = concat('Order Mainan Oleh Pelanggan ', new.nama_pelanggan);
    
    insert into log(
        aktivitas_id,
        keterangan,
        aktivitas_yang_berkaitan
    ) values (
        new.id_order,
        ket,
        new.nama_pelanggan
    );
end//
DELIMITER ;

DELIMITER //
create trigger sebelum_buat_kartu
before insert on kartu_pelanggan
for each row
begin
    declare id int;
    
    -- id_pelanggan
    select value_terakhir+1 into id from buat_id where nama_id='pelanggan';    
    set new.id_pelanggan = concat('PLG', id);
    update buat_id set value_terakhir = id where nama_id = 'pelanggan';
    
    -- tanggal_berakhir_kartu
    set new.tanggal_berakhir_kartu = date_add(new.tanggal_berakhir_kartu, interval 7 day);
end//
DELIMITER ;

DELIMITER //
create trigger setelah_buat_kartu
after insert on kartu_pelanggan
for each row
begin
    declare ket_kartu varchar(100);
    declare ket_total_harga varchar(100);
   
    update order_mainan set total_harga = total_harga * (97/100) where nama_pelanggan = new.nama_pelanggan and status_transaksi = 'Belum Dibayar';
    
    set ket_kartu = concat('Pelanggan ', new.nama_pelanggan, ' Resmi Mendapatkan Kartu Pelanggan Bronze');
    set ket_total_harga = concat('Order Yang Belum Terbayar Oleh Pelanggan ', new.nama_pelanggan, ' Kini Mendapatkan Diskon 3%');
    
    insert into log(
        aktivitas_id,
        keterangan,
        aktivitas_yang_berkaitan
    ) values (
        new.id_pelanggan,
        ket_kartu,
        new.nama_pelanggan
    ),
    (
        new.id_pelanggan,
        ket_total_harga,
        new.nama_pelanggan
    );
end//
DELIMITER ;

DELIMITER //
create trigger setelah_update_kartu
after update on kartu_pelanggan
for each row
begin
    declare ket_kartu varchar(100);
    declare ket_total_harga varchar(100);
    
    if old.tipe_kartu != new.tipe_kartu then
        if new.tipe_kartu = 'Platinum' then
            set ket_total_harga = concat('Order Yang Belum Terbayar Oleh Pelanggan ', new.nama_pelanggan, ' Kini Mendapatkan Diskon 6%');
            update order_mainan set total_harga = total_harga * (97/100) where nama_pelanggan = new.nama_pelanggan and status_transaksi = 'Belum Dibayar';
        else
            set ket_total_harga = concat('Order Yang Belum Terbayar Oleh Pelanggan ', new.nama_pelanggan, ' Kini Mendapatkan Diskon 9%');
            update order_mainan set total_harga = total_harga * (94/100) where nama_pelanggan = new.nama_pelanggan and status_transaksi = 'Belum Dibayar';
        end if;
        set ket_kartu = concat('Pelanggan ', new.nama_pelanggan, ' Resmi Mengupgrade Kartu Pelanggan Menjadi ', new.tipe_kartu, ' Dari ', old.tipe_kartu);
        insert into log(
        aktivitas_id,
        keterangan,
        aktivitas_yang_berkaitan
        ) values (
            new.id_pelanggan,
            ket_kartu,
            new.nama_pelanggan
        ),
        (
            new.id_pelanggan,
            ket_total_harga,
            new.nama_pelanggan
        );
    end if;
end//
DELIMITER ;

DELIMITER //
create trigger sebelum_bayar_order
before update on bayar_order_mainan
for each row
begin
    if new.id_metode = 'MTD1' or new.id_metode = 'MTD2' or new.id_metode = 'MTD3' or new.id_metode = 'MTD4' or new.id_metode = 'MTD5' then
        update order_mainan set status_transaksi = 'Dibayar' where id_order = new.id_order;
    else
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Metode Pembayaran Tidak Valid';
    end if;
end//
DELIMITER ;

DELIMITER //
create trigger setelah_bayar_order
after update on bayar_order_mainan
for each row
begin
    declare id int;
    declare kriteria int;
    declare kuantitas_var int;
    declare kapasitas_sebelum int;
    declare kapasitas_sesudah int;
    declare ket_bayar varchar(100);
    declare ket_rak varchar(100);
    declare nama_pelanggan_var varchar(20);
    declare metode_var varchar(20);
    declare mainan_id varchar(10);
    declare rak_id varchar(10);
    declare pelanggan_id varchar(10);
    
    select id_mainan, nama_pelanggan, kuantitas into mainan_id, nama_pelanggan_var, kuantitas_var from order_mainan where id_order = new.id_order;
    select metode into metode_var from metode_pembayaran where id_metode = new.id_metode;
    select id_rak into rak_id from mainan where id_mainan = mainan_id;
    select kapasitas into kapasitas_sebelum from rak_kapasitas_mainan where id_rak = rak_id;
    select count(*) into kriteria from order_mainan where nama_pelanggan = nama_pelanggan_var and status_transaksi = 'Dibayar';
    
    update mainan set stok = stok - kuantitas_var where id_mainan = mainan_id;
    update rak_kapasitas_mainan set kapasitas = kapasitas + kuantitas_var where id_rak = rak_id;
    
    select kapasitas into kapasitas_sesudah from rak_kapasitas_mainan where id_rak = rak_id;
    
    set ket_bayar = concat('Order Berhasil Dibayar Oleh Pelanggan ', nama_pelanggan_var, ' Dengan Metode Pembayaran ', metode_var);
    set ket_rak = concat('Kapasitas Rak Bertambah Dari ', kapasitas_sebelum, ' Menjadi ', kapasitas_sesudah);
    
    insert into log(
        aktivitas_id,
        keterangan,
        aktivitas_yang_berkaitan
    ) values
    (
        new.id_order,
        ket_bayar,
        nama_pelanggan_var
    ),
    (
        rak_id,
        ket_rak,
        new.id_order
    );
    
    if kriteria = 3 then
        insert into kartu_pelanggan (
            nama_pelanggan,
            tipe_kartu
        ) values (
            nama_pelanggan_var,
            'Bronze'
        );
    elseif kriteria = 6 then
        update kartu_pelanggan set tipe_kartu = 'Platinum', tanggal_berakhir_kartu = date_add(tanggal_berakhir_kartu, interval 3 day) where nama_pelanggan = nama_pelanggan_var;
    elseif kriteria = 10 then
        update kartu_pelanggan set tipe_kartu = 'Gold', tanggal_berakhir_kartu = date_add(tanggal_berakhir_kartu, interval 3 day) where nama_pelanggan = nama_pelanggan_var;
    elseif kriteria > 3 and kriteria != 6 and kriteria != 10 then
        update kartu_pelanggan set tanggal_berakhir_kartu = date_add(tanggal_berakhir_kartu, interval 3 day);
    end if;
end//
DELIMITER ;

DELIMITER //
create trigger sebelum_tambah_mainan
before insert on mainan
for each row
begin
    declare id int;
    declare kapasitas_var int;
    
    select kapasitas into kapasitas_var from rak_kapasitas_mainan where id_rak = new.id_rak;
    
    -- kondisi jika mainan melebihi kapasitas penyimpanan rak
    if new.stok > kapasitas_var then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stok Mainan Melebihi Kapasitas Rak';
    elseif new.stok > 30 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stok Mainan Maksimal 30';
    elseif new.stok < 3 then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stok Mainan Minimal 3';
    else
        -- id_mainan
        select value_terakhir+1 into id from buat_id where nama_id = 'mainan';    
        set new.id_mainan = concat('MN', id);
        update buat_id set value_terakhir = id where nama_id = 'mainan';
    end if;
end//
DELIMITER ;

DELIMITER //
create trigger setelah_tambah_mainan
after insert on mainan
for each row
begin
    declare kapasitas_sebelum int;
    declare kapasitas_sesudah int;
    declare ket_tambah varchar(100);
    declare ket_rak varchar(100);
    
    select kapasitas into kapasitas_sebelum from rak_kapasitas_mainan where id_rak = new.id_rak;
    -- update kapasitas rak
    update rak_kapasitas_mainan set kapasitas = kapasitas - new.stok where id_rak = new.id_rak;
    select kapasitas into kapasitas_sesudah from rak_kapasitas_mainan where id_rak = new.id_rak;
        
    set ket_tambah = concat('Mainan Berhasil Ditambahkan Ke ', new.id_rak);
    set ket_rak = concat('Kapasitas Rak Berkurang Dari ', kapasitas_sebelum, ' Menjadi ', kapasitas_sesudah);
    
    insert into log(
        aktivitas_id,
        keterangan,
        aktivitas_yang_berkaitan
    ) values (
        new.id_mainan,
        ket_tambah,
        new.id_rak
    ),
    (
        new.id_rak,
        ket_rak,
        new.id_mainan
    );
end//
DELIMITER ;

-- Uji Coba

-- Blok Dari Sini (1)
-- Tambah Penjualan Mainan Ke Rak Yang Disediakan
insert into mainan (id_rak, nama_mainan, kategori, harga_satuan, stok)
values
('RAK1', 'Menara Monas', 'Miniatur', 42000.00, 30),
('RAK2', 'Cristiano Ronaldo', 'Action Figure', 110000.00, 30),
('RAK3', 'Rubik', 'Edukasi', 12000.00, 30),
('RAK2', 'Robot Hiu', 'Robot', 56000.00, 30),
('RAK2', 'Optimus Prime', 'Action Figure', 130000.00, 15);

-- Melihat Mainan Yang Baru Ditambahkan
select * from mainan;
-- Melihat Kapasitas RAK Setelah Menambahkan Mainan Ke RAK
select * from rak_kapasitas_mainan;
-- Melihat Log Aktivitas
select * from log;
-- Sampai Sini (1)

-- Blok Dari Sini (2)
-- Order Mainan
insert into order_mainan (id_mainan, nama_pelanggan, kuantitas) values
('MN4', 'Ahmad Nur Huda', 16),
('MN1', 'Nur Huda', 7),
('MN5', 'Nur Huda', 2),
('MN3', 'Ahmad Nur Huda', 5),
('MN5', 'Ahmad Nur Huda', 3),
('MN2', 'Ahmad Nur Huda', 2),
('MN4', 'Ahmad Nur', 3),
('MN4', 'Ahmad Nur Huda', 1),
('MN2', 'Ahmad Nur Huda', 6),
('MN2', 'Uda', 1),
('MN3', 'Ahmad Nur Huda', 14),
('MN1', 'Ahmad Nur Huda', 4);

-- Melihat Update Order Mainan Setelah Menambahkan Order
select * from order_mainan;
-- Melihat Halaman Pembayaran Setelah Menambahkan Order
select * from bayar_order_mainan;
-- Melihat Log Aktivitas
select * from log;
-- Sampai Sini (2)

-- Blok Dari Sini (3)
-- Bayar Order Mainan (Sekali)
update bayar_order_mainan set id_metode='MTD1' where id_order='ORD3';

-- Melihat Status Transaksi Setelah Membayar Order
select id_order, nama_pelanggan, total_harga, status_transaksi from order_mainan;
-- Melihat Update Jumlah Stok Mainan Setelah Membayar Order
select * from mainan;
-- Melihat Update Kapasitas Rak Setelah Membayar Order
select * from rak_kapasitas_mainan;
-- Melihat Kartu Pelanggan Setelah Membayar Order
select * from kartu_pelanggan;
-- Melihat Log Aktivitas
select * from log;
-- Sampai Sini (3)

-- Blok Dari Sini (4)
-- Bayar Beberapa Order Mainan (Lebih Dari Sekali)
update bayar_order_mainan set id_metode='MTD5' where id_order='ORD1';
update bayar_order_mainan set id_metode='MTD2' where id_order='ORD4';
update bayar_order_mainan set id_metode='MTD4' where id_order='ORD5';
update bayar_order_mainan set id_metode='MTD1' where id_order='ORD6';

-- Melihat Status Transaksi Setelah Membayar Order
select id_order, nama_pelanggan, total_harga, status_transaksi from order_mainan;
-- Melihat Update Jumlah Stok Mainan Setelah Membayar Order
select * from mainan;
-- Melihat Update Kapasitas Rak Setelah Membayar Order
select * from rak_kapasitas_mainan;
-- Melihat Kartu Pelanggan Setelah Membayar Order
select * from kartu_pelanggan;
-- Melihat Log Aktivitas
select * from log;
-- Sampai Sini (4)

-- Blok Dari Sini (5)
-- Bayar Beberapa Order Mainan Lagi (Lebih Dari Sekali)
update bayar_order_mainan set id_metode='MTD2' where id_order='ORD11';
update bayar_order_mainan set id_metode='MTD1' where id_order='ORD9';

-- Melihat Status Transaksi Setelah Membayar Order
select id_order, nama_pelanggan, total_harga, status_transaksi from order_mainan;
-- Melihat Update Jumlah Stok Mainan Setelah Membayar Order
select * from mainan;
-- Melihat Update Kapasitas Rak Setelah Membayar Order
select * from rak_kapasitas_mainan;
-- Melihat Kartu Pelanggan Setelah Membayar Order
select * from kartu_pelanggan;
-- Melihat Log Aktivitas
select * from log;
-- Sampai Sini (5)

insert into order_mainan (id_mainan, nama_pelanggan, kuantitas) values
('MN2', 'Yanto Pratama', 4),
('MN3', 'Nur Huda', 3),
('MN5', 'Lina Dewi', 6),
('MN1', 'Yanto Pratama', 2),
('MN4', 'Nur Huda', 7),
('MN2', 'Nur Huda', 8),
('MN1', 'Yanto Pratama', 5),
('MN5', 'Lina Dewi', 3),
('MN1', 'Lina Dewi', 1),
('MN4', 'Rina Suryani', 2),
('MN3', 'Yanto Pratama', 8);

update bayar_order_mainan set id_metode='MTD3' where id_order='ORD17';
update bayar_order_mainan set id_metode='MTD5' where id_order='ORD13';
select * from order_mainan order by id_order asc;

update bayar_order_mainan set id_metode='MTD1' where id_order='ORD16';
update bayar_order_mainan set id_metode='MTD4' where id_order='ORD22';

select * from bayar_order_mainan;
select * from buat_id;
select * from kartu_pelanggan;
select * from log;
select * from mainan;
select * from metode_pembayaran;
select * from order_mainan;