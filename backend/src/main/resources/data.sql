-- =====================================================
-- DATI DI ESEMPIO PER L'APPLICAZIONE DEBT COLLECTION
-- Caricato automaticamente da Hibernate all'avvio
-- =====================================================

-- USERS
INSERT INTO users (id, username, password, password_expired) VALUES 
(nextval('users_id_seq'), 'admin', '$2a$10$lfhOb5LzuZHhfW8EUU3E9uHMbGWJQpGeUUUlYS7NtZMY4VxoXwWC6', true),
(nextval('users_id_seq'), 'user', '$2a$10$KWYWnqn0ETqjrmjZX7R5EO8oEwlJuqmGgz4.eB58NQ0YrAutxzx.q', true);

-- USER ROLES
INSERT INTO user_roles (user_id, role) VALUES 
((SELECT id FROM users WHERE username = 'admin'), 'ROLE_ADMIN'),
((SELECT id FROM users WHERE username = 'user'), 'ROLE_USER');


-- DEBT CASES - Casistiche varie
INSERT INTO debt_case (id, debtor_name, owed_amount, current_state, current_state_date, next_deadline_date, ongoing_negotiations, has_installment_plan, paid, active, notes, created_date, last_modified_date, created_by, last_modified_by) VALUES
-- Caso 1: In attesa di messa in mora
(1, 'Mario Rossi', 5000.00, 'MESSA_IN_MORA_DA_FARE', '2025-04-01 10:00:00', '2025-05-01 10:00:00', false, false, false, true, 'Cliente insolvente da 6 mesi', '2025-04-01 09:00:00', '2025-04-01 09:00:00', 'system', 'system'),

-- Caso 2: Con piano rateale attivo e pagamenti parziali
(2, 'Giuseppe Verdi', 12500.00, 'DEPOSITO_RICORSO', '2025-03-15 14:30:00', '2025-04-29 14:30:00', true, true, false, true, 'Accordo di pagamento rateale non rispettato', '2025-03-15 13:30:00', '2025-03-15 13:30:00', 'system', 'system'),

-- Caso 3: Decreto ingiuntivo da notificare
(3, 'Francesco Bianchi', 8750.00, 'DECRETO_INGIUNTIVO_DA_NOTIFICARE', '2025-05-01 16:20:00', '2025-05-31 16:20:00', false, false, false, true, 'Nessuna risposta dopo notifica decreto ingiuntivo', '2025-05-01 15:20:00', '2025-05-01 15:20:00', 'system', 'system'),

-- Caso 4: Completamente pagato
(4, 'Anna Neri', 3200.00, 'COMPLETATA', '2025-06-15 11:00:00', null, false, false, true, true, 'Pagamento completo ricevuto in unica soluzione', '2025-02-10 09:00:00', '2025-06-15 11:00:00', 'system', 'system'),

-- Caso 5: Con pagamenti parziali frequenti
(5, 'Luca Ferrari', 15000.00, 'MESSA_IN_MORA_INVIATA', '2025-01-20 09:15:00', '2025-08-15 09:15:00', true, true, false, true, 'Piano rateale con pagamenti irregolari ma costanti', '2025-01-10 08:00:00', '2025-07-10 14:30:00', 'system', 'system'),

-- Caso 6: Scaduto da molto tempo
(6, 'Paola Gialli', 25000.00, 'PIGNORAMENTO', '2024-11-01 10:00:00', '2025-09-01 10:00:00', false, false, false, true, 'Caso complesso, debitore irreperibile', '2024-06-01 09:00:00', '2025-07-01 15:00:00', 'system', 'system'),

-- Caso 7: Negoziazione in corso
(7, 'Roberto Blu', 7800.00, 'CONTESTAZIONE_DA_RISCONTRARE', '2025-07-01 14:00:00', '2025-07-30 14:00:00', true, false, false, true, 'In trattativa per accordo stragiudiziale', '2025-06-15 10:00:00', '2025-07-01 14:00:00', 'system', 'system'),

-- Caso 8: Piano rateale rispettato
(8, 'Elena Verde', 9500.00, 'MESSA_IN_MORA_INVIATA', '2025-03-01 09:00:00', '2025-08-01 09:00:00', false, true, false, true, 'Piano rateale di 12 mesi, pagamenti regolari', '2025-02-15 08:30:00', '2025-07-01 10:15:00', 'system', 'system'),

-- Caso 9: Urgente con scadenza imminente
(9, 'Marco Viola', 18750.00, 'DECRETO_INGIUNTIVO_NOTIFICATO', '2025-07-10 16:45:00', '2025-07-20 16:45:00', false, false, false, true, 'Scadenza imminente per opposizione', '2025-06-20 09:00:00', '2025-07-10 16:45:00', 'system', 'system'),

-- Caso 10: Piccolo importo, gestione semplificata
(10, 'Sara Rosa', 850.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-05 12:00:00', '2025-07-25 12:00:00', false, false, false, true, 'Importo minimo, primo sollecito', '2025-07-01 11:00:00', '2025-07-05 12:00:00', 'system', 'system'),

-- Caso 11: Con pagamento parziale recente
(11, 'Davide Arancio', 6200.00, 'MESSA_IN_MORA_INVIATA', '2025-04-10 10:30:00', '2025-08-10 10:30:00', true, false, false, true, 'Pagamento parziale ricevuto, in attesa saldo', '2025-03-15 09:00:00', '2025-07-08 14:20:00', 'system', 'system'),

-- Caso 12: Caso risolto con transazione
(12, 'Giulia Celeste', 4500.00, 'COMPLETATA', '2025-06-30 15:00:00', null, false, false, true, true, 'Risolto con accordo transattivo al 80% del debito', '2025-04-01 09:00:00', '2025-06-30 15:00:00', 'system', 'system'),

-- CASI AGGIUNTIVI (13-52) per raggiungere 52 casi totali

-- Caso 13-20: Altri casi MESSA_IN_MORA_DA_FARE
(13, 'Alessandro Bianchi', 3500.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-01 09:00:00', '2025-08-01 09:00:00', false, false, false, true, 'Primo sollecito non pagato', '2025-06-15 08:00:00', '2025-07-01 09:00:00', 'system', 'system'),
(14, 'Francesca Marini', 7200.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-05 11:30:00', '2025-08-05 11:30:00', false, false, false, true, 'Fattura scaduta da 45 giorni', '2025-05-20 10:00:00', '2025-07-05 11:30:00', 'system', 'system'),
(15, 'Giorgio Lombardi', 2800.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-08 14:00:00', '2025-08-08 14:00:00', false, false, false, true, 'Cliente abituale, primo ritardo', '2025-06-25 09:30:00', '2025-07-08 14:00:00', 'system', 'system'),
(16, 'Valentina Conti', 4900.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-09 10:15:00', '2025-08-09 10:15:00', false, false, false, true, 'Servizi professionali non pagati', '2025-06-01 08:45:00', '2025-07-09 10:15:00', 'system', 'system'),
(17, 'Matteo Ricci', 1500.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-10 16:20:00', '2025-08-10 16:20:00', false, false, false, true, 'Piccolo credito commerciale', '2025-06-28 14:10:00', '2025-07-10 16:20:00', 'system', 'system'),
(18, 'Silvia Moretti', 6700.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-11 12:45:00', '2025-08-11 12:45:00', false, false, false, true, 'Forniture aziendali', '2025-05-15 11:20:00', '2025-07-11 12:45:00', 'system', 'system'),
(19, 'Andrea Galli', 3300.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-12 08:30:00', '2025-08-12 08:30:00', false, false, false, true, 'Consulenza tecnica', '2025-06-10 15:00:00', '2025-07-12 08:30:00', 'system', 'system'),
(20, 'Chiara Romano', 8900.00, 'MESSA_IN_MORA_DA_FARE', '2025-07-12 15:00:00', '2025-08-12 15:00:00', false, false, false, true, 'Contratto di servizio', '2025-05-30 10:30:00', '2025-07-12 15:00:00', 'system', 'system'),

-- Caso 21-28: MESSA_IN_MORA_INVIATA con varie situazioni
(21, 'Fabio Santoro', 5600.00, 'MESSA_IN_MORA_INVIATA', '2025-06-15 10:00:00', '2025-07-30 10:00:00', false, false, false, true, 'Messa in mora inviata, in attesa risposta', '2025-05-20 09:15:00', '2025-06-15 10:00:00', 'system', 'system'),
(22, 'Monica De Luca', 12800.00, 'MESSA_IN_MORA_INVIATA', '2025-06-20 14:30:00', '2025-08-20 14:30:00', true, false, false, true, 'Proposta di piano rateale in valutazione', '2025-04-10 11:00:00', '2025-06-20 14:30:00', 'system', 'system'),
(23, 'Simone Ferretti', 4200.00, 'MESSA_IN_MORA_INVIATA', '2025-06-25 09:45:00', '2025-08-25 09:45:00', false, false, false, true, 'Secondo sollecito inviato', '2025-05-05 13:20:00', '2025-06-25 09:45:00', 'system', 'system'),
(24, 'Roberta Greco', 7800.00, 'MESSA_IN_MORA_INVIATA', '2025-07-01 11:20:00', '2025-09-01 11:20:00', true, true, false, true, 'Piano rateale proposto dal debitore', '2025-04-25 08:40:00', '2025-07-01 11:20:00', 'system', 'system'),
(25, 'Davide Mancini', 9400.00, 'MESSA_IN_MORA_INVIATA', '2025-07-03 16:10:00', '2025-09-03 16:10:00', false, false, false, true, 'Azienda in difficoltà finanziarie', '2025-03-15 10:25:00', '2025-07-03 16:10:00', 'system', 'system'),
(26, 'Laura Barbieri', 3700.00, 'MESSA_IN_MORA_INVIATA', '2025-07-05 13:55:00', '2025-09-05 13:55:00', false, false, false, true, 'Contestazione parziale ricevuta', '2025-05-12 12:15:00', '2025-07-05 13:55:00', 'system', 'system'),
(27, 'Stefano Pellegrini', 11200.00, 'MESSA_IN_MORA_INVIATA', '2025-07-08 10:40:00', '2025-09-08 10:40:00', true, false, false, true, 'Richiesta dilazione termini', '2025-04-02 14:50:00', '2025-07-08 10:40:00', 'system', 'system'),
(28, 'Paola Martelli', 6300.00, 'MESSA_IN_MORA_INVIATA', '2025-07-10 15:25:00', '2025-09-10 15:25:00', false, false, false, true, 'Nessuna risposta ricevuta', '2025-05-01 09:10:00', '2025-07-10 15:25:00', 'system', 'system'),

-- Caso 29-34: CONTESTAZIONE_DA_RISCONTRARE
(29, 'Marco Benedetti', 8500.00, 'CONTESTAZIONE_DA_RISCONTRARE', '2025-06-10 09:30:00', '2025-08-10 09:30:00', true, false, false, true, 'Contestazione su qualità servizi', '2025-04-20 11:45:00', '2025-06-10 09:30:00', 'system', 'system'),
(30, 'Alessia Fontana', 5900.00, 'CONTESTAZIONE_DA_RISCONTRARE', '2025-06-18 14:15:00', '2025-08-18 14:15:00', true, false, false, true, 'Disaccordo su importo fatturato', '2025-05-08 16:20:00', '2025-06-18 14:15:00', 'system', 'system'),
(31, 'Federico Villa', 13700.00, 'CONTESTAZIONE_DA_RISCONTRARE', '2025-06-22 11:50:00', '2025-08-22 11:50:00', true, false, false, true, 'Contestazione termini contrattuali', '2025-03-10 08:30:00', '2025-06-22 11:50:00', 'system', 'system'),
(32, 'Giuliana Sartori', 4600.00, 'CONTESTAZIONE_DA_RISCONTRARE', '2025-06-28 16:40:00', '2025-08-28 16:40:00', true, false, false, true, 'Richiesta documentazione aggiuntiva', '2025-05-18 13:15:00', '2025-06-28 16:40:00', 'system', 'system'),
(33, 'Claudio Rinaldi', 7200.00, 'CONTESTAZIONE_DA_RISCONTRARE', '2025-07-02 12:20:00', '2025-09-02 12:20:00', true, false, false, true, 'Mediazione in corso', '2025-04-15 10:05:00', '2025-07-02 12:20:00', 'system', 'system'),
(34, 'Serena Colombo', 9800.00, 'CONTESTAZIONE_DA_RISCONTRARE', '2025-07-06 09:10:00', '2025-09-06 09:10:00', true, false, false, true, 'Proposta di accordo stragiudiziale', '2025-03-25 15:40:00', '2025-07-06 09:10:00', 'system', 'system'),

-- Caso 35-40: DEPOSITO_RICORSO
(35, 'Antonio Marchetti', 16400.00, 'DEPOSITO_RICORSO', '2025-05-15 10:30:00', '2025-08-15 10:30:00', false, false, false, true, 'Ricorso depositato in tribunale', '2025-02-20 09:20:00', '2025-05-15 10:30:00', 'system', 'system'),
(36, 'Isabella Gatti', 11900.00, 'DEPOSITO_RICORSO', '2025-05-20 14:45:00', '2025-08-20 14:45:00', false, false, false, true, 'Procedura legale avviata', '2025-03-05 11:30:00', '2025-05-20 14:45:00', 'system', 'system'),
(37, 'Emanuele Caruso', 22300.00, 'DEPOSITO_RICORSO', '2025-05-25 16:20:00', '2025-08-25 16:20:00', false, false, false, true, 'Caso complesso, importo elevato', '2025-01-10 08:15:00', '2025-05-25 16:20:00', 'system', 'system'),
(38, 'Cristina Palmieri', 8700.00, 'DEPOSITO_RICORSO', '2025-06-01 12:10:00', '2025-09-01 12:10:00', false, false, false, true, 'Udienza fissata', '2025-03-20 14:25:00', '2025-06-01 12:10:00', 'system', 'system'),
(39, 'Riccardo Monti', 14600.00, 'DEPOSITO_RICORSO', '2025-06-08 09:55:00', '2025-09-08 09:55:00', false, false, false, true, 'In attesa decreto', '2025-02-28 16:40:00', '2025-06-08 09:55:00', 'system', 'system'),
(40, 'Nicoletta Fabbri', 19200.00, 'DEPOSITO_RICORSO', '2025-06-12 15:30:00', '2025-09-12 15:30:00', false, false, false, true, 'Documentazione completata', '2025-01-25 10:50:00', '2025-06-12 15:30:00', 'system', 'system'),

-- Caso 41-46: DECRETO_INGIUNTIVO_DA_NOTIFICARE e DECRETO_INGIUNTIVO_NOTIFICATO
(41, 'Massimo Leone', 17800.00, 'DECRETO_INGIUNTIVO_DA_NOTIFICARE', '2025-06-20 11:15:00', '2025-07-20 11:15:00', false, false, false, true, 'Decreto emesso, da notificare', '2025-01-15 09:30:00', '2025-06-20 11:15:00', 'system', 'system'),
(42, 'Ornella Bassi', 13400.00, 'DECRETO_INGIUNTIVO_DA_NOTIFICARE', '2025-06-25 13:40:00', '2025-07-25 13:40:00', false, false, false, true, 'Preparazione notifica', '2025-02-08 12:20:00', '2025-06-25 13:40:00', 'system', 'system'),
(43, 'Vincenzo Donati', 21600.00, 'DECRETO_INGIUNTIVO_NOTIFICATO', '2025-07-01 10:20:00', '2025-08-01 10:20:00', false, false, false, true, 'Notifica avvenuta, termine opposizione', '2025-12-20 15:10:00', '2025-07-01 10:20:00', 'system', 'system'),
(44, 'Federica Cattaneo', 9600.00, 'DECRETO_INGIUNTIVO_NOTIFICATO', '2025-07-05 14:50:00', '2025-08-05 14:50:00', false, false, false, true, 'In attesa scadenza termini', '2025-01-30 11:40:00', '2025-07-05 14:50:00', 'system', 'system'),
(45, 'Gianluca Mariani', 18900.00, 'DECRETO_INGIUNTIVO_NOTIFICATO', '2025-07-08 16:30:00', '2025-08-08 16:30:00', false, false, false, true, 'Monitoraggio opposizione', '2025-01-05 08:25:00', '2025-07-08 16:30:00', 'system', 'system'),
(46, 'Tiziana Guerra', 12100.00, 'DECRETO_INGIUNTIVO_NOTIFICATO', '2025-07-10 12:05:00', '2025-08-10 12:05:00', false, false, false, true, 'Scadenza imminente', '2025-02-15 14:15:00', '2025-07-10 12:05:00', 'system', 'system'),

-- Caso 47-50: PRECETTO e PIGNORAMENTO
(47, 'Domenico Ferri', 24700.00, 'PRECETTO', '2025-04-10 09:45:00', '2025-10-10 09:45:00', false, false, false, true, 'Precetto notificato', '2024-10-20 11:30:00', '2025-04-10 09:45:00', 'system', 'system'),
(48, 'Manuela Rossi', 31200.00, 'PRECETTO', '2025-04-20 15:20:00', '2025-10-20 15:20:00', false, false, false, true, 'Termini precetto in corso', '2024-09-15 13:45:00', '2025-04-20 15:20:00', 'system', 'system'),
(49, 'Salvatore Bruno', 28900.00, 'PIGNORAMENTO', '2025-03-25 11:10:00', '2025-12-25 11:10:00', false, false, false, true, 'Pignoramento mobiliare in corso', '2024-08-10 10:20:00', '2025-03-25 11:10:00', 'system', 'system'),
(50, 'Franca Milani', 35600.00, 'PIGNORAMENTO', '2025-03-30 14:35:00', '2025-12-30 14:35:00', false, false, false, true, 'Pignoramento immobiliare', '2024-07-25 16:50:00', '2025-03-30 14:35:00', 'system', 'system'),

-- Caso 51-52: COMPLETATA
(51, 'Renato Testa', 6800.00, 'COMPLETATA', '2025-06-18 10:30:00', null, false, false, true, true, 'Pagato dopo messa in mora', '2025-04-10 09:15:00', '2025-06-18 10:30:00', 'system', 'system'),
(52, 'Giovanna Pozzi', 9300.00, 'COMPLETATA', '2025-07-02 16:45:00', null, false, true, true, true, 'Completato piano rateale', '2025-01-20 12:30:00', '2025-07-02 16:45:00', 'system', 'system');

-- INSTALLMENTS - Piani rateali per debt case con has_installment_plan = true
-- All installment inserts must come after all debt_case inserts
INSERT INTO installment (id, debt_case_id, installment_number, amount, due_date, paid, paid_date, paid_amount, created_date, last_modified_date, created_by, last_modified_by) VALUES
-- Piano rateale per Giuseppe Verdi (12500.00 in 8 rate da 1562.50) - alcune pagate, alcune no
(nextval('installment_id_seq'), 2, 1, 1562.50, '2025-02-15 00:00:00', true, '2025-02-20 10:00:00', 1500.00, '2025-02-01 09:00:00', '2025-02-20 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 2, 2, 1562.50, '2025-03-15 00:00:00', true, '2025-03-20 10:00:00', 1500.00, '2025-02-01 09:00:00', '2025-03-20 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 2, 3, 1562.50, '2025-04-15 00:00:00', false, null, null, '2025-02-01 09:00:00', '2025-02-01 09:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 2, 4, 1562.50, '2025-05-15 00:00:00', true, '2025-05-15 11:30:00', 1000.00, '2025-02-01 09:00:00', '2025-05-15 11:30:00', 'system', 'system'),
(nextval('installment_id_seq'), 2, 5, 1562.50, '2025-06-15 00:00:00', false, null, null, '2025-02-01 09:00:00', '2025-02-01 09:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 2, 6, 1562.50, '2025-07-15 00:00:00', false, null, null, '2025-02-01 09:00:00', '2025-02-01 09:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 2, 7, 1562.50, '2025-08-15 00:00:00', false, null, null, '2025-02-01 09:00:00', '2025-02-01 09:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 2, 8, 1562.50, '2025-09-15 00:00:00', false, null, null, '2025-02-01 09:00:00', '2025-02-01 09:00:00', 'system', 'system'),

-- Piano rateale per Luca Ferrari (15000.00 in 10 rate da 1500.00) - pagamenti irregolari
(nextval('installment_id_seq'), 5, 1, 1500.00, '2025-02-01 00:00:00', true, '2025-02-15 14:20:00', 2000.00, '2025-01-15 08:00:00', '2025-02-15 14:20:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 2, 1500.00, '2025-03-01 00:00:00', true, '2025-03-22 09:45:00', 1800.00, '2025-01-15 08:00:00', '2025-03-22 09:45:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 3, 1500.00, '2025-04-01 00:00:00', true, '2025-04-18 16:10:00', 2200.00, '2025-01-15 08:00:00', '2025-04-18 16:10:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 4, 1500.00, '2025-05-01 00:00:00', false, null, null, '2025-01-15 08:00:00', '2025-01-15 08:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 5, 1500.00, '2025-06-01 00:00:00', true, '2025-06-05 11:25:00', 1500.00, '2025-01-15 08:00:00', '2025-06-05 11:25:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 6, 1500.00, '2025-07-01 00:00:00', true, '2025-07-08 13:40:00', 1700.00, '2025-01-15 08:00:00', '2025-07-08 13:40:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 7, 1500.00, '2025-08-01 00:00:00', false, null, null, '2025-01-15 08:00:00', '2025-01-15 08:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 8, 1500.00, '2025-09-01 00:00:00', false, null, null, '2025-01-15 08:00:00', '2025-01-15 08:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 9, 1500.00, '2025-10-01 00:00:00', false, null, null, '2025-01-15 08:00:00', '2025-01-15 08:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 5, 10, 1500.00, '2025-11-01 00:00:00', false, null, null, '2025-01-15 08:00:00', '2025-01-15 08:00:00', 'system', 'system'),

-- Piano rateale per Elena Verde (9500.00 in 12 rate da 791.67) - pagamenti regolari
(nextval('installment_id_seq'), 8, 1, 791.67, '2025-03-01 00:00:00', true, '2025-03-01 10:00:00', 800.00, '2025-02-15 08:30:00', '2025-03-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 2, 791.67, '2025-04-01 00:00:00', true, '2025-04-01 10:00:00', 800.00, '2025-02-15 08:30:00', '2025-04-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 3, 791.67, '2025-05-01 00:00:00', true, '2025-05-01 10:00:00', 800.00, '2025-02-15 08:30:00', '2025-05-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 4, 791.67, '2025-06-01 00:00:00', true, '2025-06-01 10:00:00', 800.00, '2025-02-15 08:30:00', '2025-06-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 5, 791.67, '2025-07-01 00:00:00', true, '2025-07-01 10:00:00', 800.00, '2025-02-15 08:30:00', '2025-07-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 6, 791.67, '2025-08-01 00:00:00', false, null, null, '2025-02-15 08:30:00', '2025-02-15 08:30:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 7, 791.67, '2025-09-01 00:00:00', false, null, null, '2025-02-15 08:30:00', '2025-02-15 08:30:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 8, 791.67, '2025-10-01 00:00:00', false, null, null, '2025-02-15 08:30:00', '2025-02-15 08:30:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 9, 791.67, '2025-11-01 00:00:00', false, null, null, '2025-02-15 08:30:00', '2025-02-15 08:30:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 10, 791.67, '2025-12-01 00:00:00', false, null, null, '2025-02-15 08:30:00', '2025-02-15 08:30:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 11, 791.67, '2026-01-01 00:00:00', false, null, null, '2025-02-15 08:30:00', '2025-02-15 08:30:00', 'system', 'system'),
(nextval('installment_id_seq'), 8, 12, 791.72, '2026-02-01 00:00:00', false, null, null, '2025-02-15 08:30:00', '2025-02-15 08:30:00', 'system', 'system'),

-- Piano rateale per Roberta Greco (7800.00 in 6 rate da 1300.00) - piano proposto dal debitore
(nextval('installment_id_seq'), 24, 1, 1300.00, '2025-05-01 00:00:00', true, '2025-05-01 11:00:00', 1300.00, '2025-04-25 08:40:00', '2025-05-01 11:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 24, 2, 1300.00, '2025-06-01 00:00:00', true, '2025-06-01 11:00:00', 1300.00, '2025-04-25 08:40:00', '2025-06-01 11:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 24, 3, 1300.00, '2025-07-01 00:00:00', true, '2025-07-01 11:00:00', 1300.00, '2025-04-25 08:40:00', '2025-07-01 11:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 24, 4, 1300.00, '2025-08-01 00:00:00', false, null, null, '2025-04-25 08:40:00', '2025-04-25 08:40:00', 'system', 'system'),
(nextval('installment_id_seq'), 24, 5, 1300.00, '2025-09-01 00:00:00', false, null, null, '2025-04-25 08:40:00', '2025-04-25 08:40:00', 'system', 'system'),
(nextval('installment_id_seq'), 24, 6, 1300.00, '2025-10-01 00:00:00', false, null, null, '2025-04-25 08:40:00', '2025-04-25 08:40:00', 'system', 'system'),

-- Piano rateale per Giovanna Pozzi (9300.00 in 6 rate da 1550.00) - completato
(nextval('installment_id_seq'), 52, 1, 1550.00, '2025-02-01 00:00:00', true, '2025-02-01 10:00:00', 1550.00, '2025-01-20 12:30:00', '2025-02-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 52, 2, 1550.00, '2025-03-01 00:00:00', true, '2025-03-01 10:00:00', 1550.00, '2025-01-20 12:30:00', '2025-03-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 52, 3, 1550.00, '2025-04-01 00:00:00', true, '2025-04-01 10:00:00', 1550.00, '2025-01-20 12:30:00', '2025-04-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 52, 4, 1550.00, '2025-05-01 00:00:00', true, '2025-05-01 10:00:00', 1550.00, '2025-01-20 12:30:00', '2025-05-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 52, 5, 1550.00, '2025-06-01 00:00:00', true, '2025-06-01 10:00:00', 1550.00, '2025-01-20 12:30:00', '2025-06-01 10:00:00', 'system', 'system'),
(nextval('installment_id_seq'), 52, 6, 1550.00, '2025-07-01 00:00:00', true, '2025-07-01 10:00:00', 1550.00, '2025-01-20 12:30:00', '2025-07-01 10:00:00', 'system', 'system');

-- PAYMENTS - Varie tipologie di pagamento

-- Pagamenti per Giuseppe Verdi (ID=2, piano rateale parzialmente rispettato)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 2, 1500.00, '2025-02-20', null, '2025-02-20 10:00:00', '2025-02-20 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 2, 1500.00, '2025-03-20', null, '2025-03-20 10:00:00', '2025-03-20 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 2, 1000.00, '2025-05-15', null, '2025-05-15 11:30:00', '2025-05-15 11:30:00', 'system', 'system');

-- Pagamento completo per Anna Neri (ID=4)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 4, 3200.00, '2025-06-15', null, '2025-06-15 11:00:00', '2025-06-15 11:00:00', 'system', 'system');

-- Pagamenti multipli per Luca Ferrari (ID=5, irregolari ma costanti)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 5, 2000.00, '2025-02-15', null, '2025-02-15 14:20:00', '2025-02-15 14:20:00', 'system', 'system'),
(nextval('payment_id_seq'), 5, 1800.00, '2025-03-22', null, '2025-03-22 09:45:00', '2025-03-22 09:45:00', 'system', 'system'),
(nextval('payment_id_seq'), 5, 2200.00, '2025-04-18', null, '2025-04-18 16:10:00', '2025-04-18 16:10:00', 'system', 'system'),
(nextval('payment_id_seq'), 5, 1500.00, '2025-06-05', null, '2025-06-05 11:25:00', '2025-06-05 11:25:00', 'system', 'system'),
(nextval('payment_id_seq'), 5, 1700.00, '2025-07-08', null, '2025-07-08 13:40:00', '2025-07-08 13:40:00', 'system', 'system');

-- Piccolo pagamento per Roberto Blu (ID=7, acconto durante negoziazione)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 7, 500.00, '2025-07-02', null, '2025-07-02 16:15:00', '2025-07-02 16:15:00', 'system', 'system');

-- Pagamenti regolari per Elena Verde (ID=8, piano rateale rispettato)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 8, 800.00, '2025-03-01', null, '2025-03-01 10:00:00', '2025-03-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 8, 800.00, '2025-04-01', null, '2025-04-01 10:00:00', '2025-04-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 8, 800.00, '2025-05-01', null, '2025-05-01 10:00:00', '2025-05-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 8, 800.00, '2025-06-01', null, '2025-06-01 10:00:00', '2025-06-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 8, 800.00, '2025-07-01', null, '2025-07-01 10:00:00', '2025-07-01 10:00:00', 'system', 'system');

-- Pagamento parziale per Davide Arancio (ID=11)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 11, 2200.00, '2025-07-08', null, '2025-07-08 14:20:00', '2025-07-08 14:20:00', 'system', 'system');

-- Pagamento transattivo per Giulia Celeste (ID=12, 80% del debito)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 12, 3600.00, '2025-06-30', null, '2025-06-30 15:00:00', '2025-06-30 15:00:00', 'system', 'system');

-- PAGAMENTI AGGIUNTIVI per i nuovi casi

-- Pagamento parziale per Alessandro Bianchi (ID=13)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 13, 1000.00, '2025-07-10', null, '2025-07-10 14:20:00', '2025-07-10 14:20:00', 'system', 'system');

-- Pagamenti per Francesca Marini (ID=14)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 14, 2400.00, '2025-06-20', null, '2025-06-20 09:30:00', '2025-06-20 09:30:00', 'system', 'system'),
(nextval('payment_id_seq'), 14, 1800.00, '2025-07-10', null, '2025-07-10 15:45:00', '2025-07-10 15:45:00', 'system', 'system');

-- Piccoli pagamenti per Matteo Ricci (ID=17)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 17, 500.00, '2025-07-05', null, '2025-07-05 16:10:00', '2025-07-05 16:10:00', 'system', 'system'),
(nextval('payment_id_seq'), 17, 300.00, '2025-07-12', null, '2025-07-12 10:25:00', '2025-07-12 10:25:00', 'system', 'system');

-- Pagamenti parziali per Fabio Santoro (ID=21)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 21, 1800.00, '2025-06-30', null, '2025-06-30 16:20:00', '2025-06-30 16:20:00', 'system', 'system'),
(nextval('payment_id_seq'), 21, 2000.00, '2025-07-11', null, '2025-07-11 11:40:00', '2025-07-11 11:40:00', 'system', 'system');

-- Pagamenti parziali per Monica De Luca (ID=22)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 22, 2000.00, '2025-05-15', null, '2025-05-15 10:30:00', '2025-05-15 10:30:00', 'system', 'system'),
(nextval('payment_id_seq'), 22, 2000.00, '2025-06-15', null, '2025-06-15 10:30:00', '2025-06-15 10:30:00', 'system', 'system');

-- Pagamento per Simone Ferretti (ID=23)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 23, 1200.00, '2025-07-08', null, '2025-07-08 13:25:00', '2025-07-08 13:25:00', 'system', 'system');

-- Pagamenti rateali per Roberta Greco (ID=24)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 24, 1300.00, '2025-05-01', null, '2025-05-01 11:00:00', '2025-05-01 11:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 24, 1300.00, '2025-06-01', null, '2025-06-01 11:00:00', '2025-06-01 11:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 24, 1300.00, '2025-07-01', null, '2025-07-01 11:00:00', '2025-07-01 11:00:00', 'system', 'system');

-- Pagamento per Laura Barbieri (ID=26)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 26, 800.00, '2025-07-12', null, '2025-07-12 15:10:00', '2025-07-12 15:10:00', 'system', 'system');

-- Pagamento per Stefano Pellegrini (ID=27)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 27, 3000.00, '2025-07-06', null, '2025-07-06 12:35:00', '2025-07-06 12:35:00', 'system', 'system');

-- Acconti durante contestazioni
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 29, 2000.00, '2025-06-20', null, '2025-06-20 11:15:00', '2025-06-20 11:15:00', 'system', 'system'), -- Marco Benedetti
(nextval('payment_id_seq'), 30, 1500.00, '2025-06-25', null, '2025-06-25 14:30:00', '2025-06-25 14:30:00', 'system', 'system'), -- Alessia Fontana
(nextval('payment_id_seq'), 31, 3000.00, '2025-07-01', null, '2025-07-01 09:45:00', '2025-07-01 09:45:00', 'system', 'system'); -- Federico Villa

-- Pagamento per Claudio Rinaldi (ID=33)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 33, 2400.00, '2025-07-09', null, '2025-07-09 14:15:00', '2025-07-09 14:15:00', 'system', 'system');

-- Pagamento completo per Renato Testa (ID=51)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 51, 6800.00, '2025-06-18', null, '2025-06-18 10:30:00', '2025-06-18 10:30:00', 'system', 'system');

-- Pagamenti rateali completati per Giovanna Pozzi (ID=52)
INSERT INTO payment (id, debt_case_id, amount, payment_date, installment_id, created_date, last_modified_date, created_by, last_modified_by) VALUES
(nextval('payment_id_seq'), 52, 1550.00, '2025-02-01', null, '2025-02-01 10:00:00', '2025-02-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 52, 1550.00, '2025-03-01', null, '2025-03-01 10:00:00', '2025-03-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 52, 1550.00, '2025-04-01', null, '2025-04-01 10:00:00', '2025-04-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 52, 1550.00, '2025-05-01', null, '2025-05-01 10:00:00', '2025-05-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 52, 1550.00, '2025-06-01', null, '2025-06-01 10:00:00', '2025-06-01 10:00:00', 'system', 'system'),
(nextval('payment_id_seq'), 52, 1550.00, '2025-07-01', null, '2025-07-01 10:00:00', '2025-07-01 10:00:00', 'system', 'system');
