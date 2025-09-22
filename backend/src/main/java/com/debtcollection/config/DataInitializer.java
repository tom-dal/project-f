package com.debtcollection.config;

import com.debtcollection.model.User;
import com.debtcollection.model.DebtCase;
import com.debtcollection.model.CaseState;
import com.debtcollection.model.Installment;
import com.debtcollection.model.Payment;
import com.debtcollection.repository.UserRepository;
import com.debtcollection.repository.DebtCaseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.context.annotation.Profile; // added

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors; // added for post-processing

/**
 * USER PREFERENCE: Data initializer for MongoDB
 * Initializes test user and sample debt cases when application starts up
 */
@Component
@Profile({"dev","test"}) // USER PREFERENCE: restrict seeding to non-production profiles
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final DebtCaseRepository debtCaseRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) throws Exception {
        initializeTestUser();
        initializeTestData();
    }

    private void initializeTestUser() {
        // Check if admin user already exists
        if (userRepository.findByUsername("admin").isPresent()) {
            log.info("Admin user already exists, skipping initialization");
            return;
        }

        // Create admin user with default password
        User adminUser = new User();
        adminUser.setUsername("admin");
        adminUser.setPassword(passwordEncoder.encode("admin")); // Default password from instructions
        adminUser.setPasswordExpired(true); // USER PREFERENCE: Force password change on first login
        adminUser.setRoles(Set.of("ADMIN", "USER"));

        userRepository.save(adminUser);
        log.info("✅ Admin user created successfully with username: admin, password: admin (change required)");
        log.info("🔐 Default login: username=admin, password=admin -> change password required");
    }

    private void initializeTestData() {
        // Check if test data already exists
        if (debtCaseRepository.count() > 0) {
            log.info("Test debt cases already exist, skipping initialization");
            return;
        }

        log.info("🔄 Creating test debt cases...");

        List<DebtCase> testCases = new ArrayList<>();
        Random random = new Random(42); // Fixed seed for consistent test data

        // Generate 100 unique debtor names (deterministic)
        String[] firstNames = {
            "Mario","Giuseppe","Anna","Francesco","Maria","Luigi","Giovanna","Antonio","Elena","Marco",
            "Francesca","Roberto","Giulia","Andrea","Paola","Davide","Chiara","Stefano","Valentina","Matteo",
            "Simona","Federico","Alessia","Luca","Serena","Nicola","Cristina","Daniele","Michela","Fabio"
        };
        String[] lastNames = {
            "Rossi","Verdi","Bianchi","Neri","Ferrari","Romano","Ricci","Conti","Russo","Marino",
            "Costa","Rizzo","Fontana","Greco","Bruno","Leone","Galli","Villa","Barbieri","Colombo",
            "Lombardi","Martinelli","Santoro","Fiore","Marchetti","Pellegrini","De Luca","Moretti","Gatti","Esposito"
        };
        List<String> uniqueNames = new ArrayList<>();
        outer: for (String fn : firstNames) {
            for (String ln : lastNames) {
                uniqueNames.add(fn + " " + ln);
                if (uniqueNames.size() == 100) break outer;
            }
        }
        // Shuffle for variety but deterministic due to seed
        java.util.Collections.shuffle(uniqueNames, random);

        CaseState[] states = CaseState.values();

        // Create 100 test cases with realistic distribution
        for (int i = 0; i < 100; i++) {
            DebtCase debtCase = new DebtCase();

            // Debtor name (already unique, no suffixes)
            debtCase.setDebtorName(uniqueNames.get(i));

            // Realistic amounts (€500 to €50,000)
            double amount = 500 + random.nextDouble() * 49500;
            debtCase.setOwedAmount(Math.round(amount * 100.0) / 100.0); // Round to 2 decimal places

            // Weighted state distribution (more cases in early states)
            CaseState state;
            int stateWeight = random.nextInt(100);
            if (stateWeight < 25) {
                state = CaseState.MESSA_IN_MORA_DA_FARE;
            } else if (stateWeight < 40) {
                state = CaseState.MESSA_IN_MORA_INVIATA;
            } else if (stateWeight < 55) {
                state = CaseState.DEPOSITO_RICORSO;
            } else if (stateWeight < 70) {
                state = CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE;
            } else if (stateWeight < 80) {
                state = CaseState.DECRETO_INGIUNTIVO_NOTIFICATO;
            } else if (stateWeight < 87) {
                state = CaseState.CONTESTAZIONE_DA_RISCONTRARE;
            } else if (stateWeight < 92) {
                state = CaseState.PRECETTO;
            } else if (stateWeight < 97) {
                state = CaseState.PIGNORAMENTO;
            } else {
                state = CaseState.COMPLETATA;
            }

            debtCase.setCurrentState(state);

            // Realistic dates
            LocalDateTime baseDate = LocalDateTime.now().minusMonths(random.nextInt(12) + 1);
            debtCase.setCurrentStateDate(baseDate);
            debtCase.setCreatedDate(baseDate.minusDays(random.nextInt(30)));
            debtCase.setLastModifiedDate(LocalDateTime.now().minusDays(random.nextInt(7)));
            if (state != CaseState.COMPLETATA) {
                debtCase.setNextDeadlineDate(LocalDateTime.now().plusDays(random.nextInt(60) + 1));
            }

            // Installment plan generation (about 25% of cases)
            boolean createInstallmentPlan = random.nextDouble() < 0.25 && state != CaseState.COMPLETATA;
            if (createInstallmentPlan) {
                int numberOfInstallments = 3 + random.nextInt(6); // 3..8
                BigDecimal total = BigDecimal.valueOf(debtCase.getOwedAmount());
                BigDecimal base = total.divide(BigDecimal.valueOf(numberOfInstallments), 2, java.math.RoundingMode.DOWN);
                BigDecimal accumulated = BigDecimal.ZERO;
                var installments = new ArrayList<Installment>();
                for (int n = 1; n <= numberOfInstallments; n++) {
                    Installment inst = new Installment();
                    inst.setInstallmentId(UUID.randomUUID().toString());
                    inst.setInstallmentNumber(n);
                    BigDecimal installmentAmount = (n == numberOfInstallments) ? total.subtract(accumulated) : base;
                    if (installmentAmount.compareTo(BigDecimal.ZERO) <= 0) {
                        installmentAmount = BigDecimal.valueOf(1.00);
                    }
                    inst.setAmount(installmentAmount);
                    accumulated = accumulated.add(installmentAmount);
                    inst.setDueDate(LocalDateTime.now().plusMonths(n));
                    inst.setPaid(false);
                    inst.setCreatedDate(LocalDateTime.now());
                    inst.setLastModifiedDate(LocalDateTime.now());
                    inst.setCreatedBy("system");
                    inst.setLastModifiedBy("system");
                    installments.add(inst);
                }
                debtCase.setInstallments(installments);
                debtCase.setHasInstallmentPlan(true);
            } else {
                debtCase.setHasInstallmentPlan(false);
            }

            debtCase.setOngoingNegotiations(random.nextBoolean() && random.nextDouble() < 0.3);
            boolean markPaid = state == CaseState.COMPLETATA && random.nextDouble() < 0.6;
            debtCase.setPaid(markPaid ? Boolean.TRUE : Boolean.FALSE);
            if (Boolean.TRUE.equals(debtCase.getPaid())) {
                var payment = new Payment();
                payment.setPaymentId(UUID.randomUUID().toString());
                payment.setAmount(debtCase.getOwedAmount());
                payment.setPaymentDate(java.time.LocalDate.now().minusDays(1));
                payment.setCreatedDate(LocalDateTime.now().minusDays(1));
                payment.setLastModifiedDate(LocalDateTime.now().minusDays(1));
                debtCase.getPayments().add(payment);
            }

            if (random.nextDouble() < 0.4) {
                String[] noteTemplates = {
                    "Contattato debitore via telefono",
                    "Inviata comunicazione tramite PEC",
                    "Debitore ha richiesto rateizzazione",
                    "In attesa di documentazione aggiuntiva",
                    "Caso complesso - richiede analisi legale",
                    "Debitore temporaneamente irreperibile",
                    "Accordo raggiunto per pagamento dilazionato"
                };
                debtCase.setNotes(noteTemplates[random.nextInt(noteTemplates.length)]);
            }

            testCases.add(debtCase);
        }

        // USER PREFERENCE: Post-elaboration to enforce 20% expired cases (half with installment plan, half without)
        applyExpiredCasesScenario(testCases);

        // Save all test cases
        debtCaseRepository.saveAll(testCases);

        log.info("✅ Created {} test debt cases successfully", testCases.size());
        log.info("📊 Test data distribution:");
        for (CaseState state : states) {
            long count = testCases.stream().filter(dc -> dc.getCurrentState() == state).count();
            log.info("   {} cases in state: {}", count, state);
        }
        log.info("💰 Amount range: €{} - €{}",
            testCases.stream().mapToDouble(DebtCase::getOwedAmount).min().orElse(0),
            testCases.stream().mapToDouble(DebtCase::getOwedAmount).max().orElse(0));
    }

    // CUSTOM IMPLEMENTATION: Enforce deterministic scenario of expired deadlines
    private void applyExpiredCasesScenario(List<DebtCase> testCases) {
        if (testCases.isEmpty()) return;
        // Consider only non-completed cases to mark as expired
        List<DebtCase> candidates = testCases.stream()
            .filter(c -> c.getCurrentState() != CaseState.COMPLETATA)
            .collect(Collectors.toList());
        if (candidates.isEmpty()) return;

        int total = testCases.size();
        int desiredExpired = Math.max(1, (int)Math.round(total * 0.20)); // 20%
        if (desiredExpired > candidates.size()) desiredExpired = candidates.size();
        int expiredWithPlan = desiredExpired / 2; // half with installment plan
        int expiredWithoutPlan = desiredExpired - expiredWithPlan; // remaining without plan

        // Slice deterministic subsets
        List<DebtCase> expiredPlanSubset = candidates.subList(0, Math.min(expiredWithPlan, candidates.size()));
        List<DebtCase> expiredNoPlanSubset = candidates.subList(Math.min(expiredWithPlan, candidates.size()), Math.min(expiredWithPlan + expiredWithoutPlan, candidates.size()));

        LocalDateTime now = LocalDateTime.now();
        // Configure expired WITHOUT plan
        for (DebtCase c : expiredNoPlanSubset) {
            c.setHasInstallmentPlan(false);
            c.getInstallments().clear();
            // past deadline between 1 and 30 days ago (deterministic using hash of id or name)
            int offset = Math.abs(c.getDebtorName().hashCode()) % 30 + 1;
            c.setNextDeadlineDate(now.minusDays(offset));
            c.setPaid(Boolean.FALSE); // ensure not fully paid
        }

        // Configure expired WITH plan
        int index = 0;
        for (DebtCase c : expiredPlanSubset) {
            // Build a deterministic installment plan overriding any existing
            List<Installment> plan = new ArrayList<>();
            // Decide variation pattern
            int pattern = index % 3; // 0: multiple overdue unpaid, 1: mix paid+overdue, 2: single overdue
            BigDecimal totalAmount = BigDecimal.valueOf(c.getOwedAmount() != null ? c.getOwedAmount() : 1000.0);
            BigDecimal part = totalAmount.divide(BigDecimal.valueOf(5), 2, java.math.RoundingMode.DOWN);
            BigDecimal accumulated = BigDecimal.ZERO;
            for (int n = 1; n <= 5; n++) {
                Installment inst = new Installment();
                inst.setInstallmentId(UUID.randomUUID().toString());
                inst.setInstallmentNumber(n);
                BigDecimal amount = (n == 5) ? totalAmount.subtract(accumulated) : part;
                if (amount.compareTo(BigDecimal.ZERO) <= 0) amount = BigDecimal.valueOf(1.00);
                inst.setAmount(amount);
                accumulated = accumulated.add(amount);
                // Determine due dates based on pattern
                LocalDateTime due;
                switch (pattern) {
                    case 0 -> { // multiple overdue unpaid
                        if (n <= 3) {
                            int daysAgo = 40 - (n * 10); // 30,20,10 days ago pattern adjusted
                            due = now.minusDays(daysAgo);
                        } else {
                            due = now.plusDays((n - 3) * 20L); // future
                        }
                        inst.setPaid(false);
                    }
                    case 1 -> { // mix paid + overdue
                        if (n == 1) {
                            due = now.minusDays(40);
                            inst.setPaid(true);
                            inst.setPaidDate(now.minusDays(35));
                            Payment payment = new Payment();
                            payment.setPaymentId(UUID.randomUUID().toString());
                            payment.setAmount(inst.getAmount().doubleValue());
                            payment.setPaymentDate(inst.getPaidDate().toLocalDate());
                            payment.setInstallmentId(inst.getInstallmentId());
                            //payment.setCreatedDate(inst.getPaidDate());
                            //payment.setLastModifiedDate(inst.getPaidDate());
                            c.getPayments().add(payment);
                        } else if (n == 2) {
                            due = now.minusDays(10); // overdue unpaid
                            inst.setPaid(false);
                        } else {
                            due = now.plusDays(n * 15L); // future
                            inst.setPaid(false);
                        }
                    }
                    default -> { // pattern 2 single overdue
                        if (n == 1) {
                            due = now.minusDays(7); // only first overdue
                            inst.setPaid(false);
                        } else {
                            due = now.plusDays(n * 20L);
                            inst.setPaid(false);
                        }
                    }
                }
                inst.setDueDate(due);
                inst.setCreatedDate(now.minusDays(1));
                inst.setLastModifiedDate(now.minusHours(1));
                inst.setCreatedBy("system");
                inst.setLastModifiedBy("system");
                plan.add(inst);
            }
            c.setInstallments(plan);
            c.setHasInstallmentPlan(true);
            c.setPaid(Boolean.FALSE); // ensure case itself not fully paid
            // nextDeadlineDate set to earliest overdue unpaid installment (past)
            LocalDateTime earliestPast = plan.stream()
                .filter(inst -> Boolean.FALSE.equals(inst.getPaid()) && inst.getDueDate().isBefore(now))
                .map(Installment::getDueDate)
                .sorted()
                .findFirst()
                .orElse(now.minusDays(5));
            c.setNextDeadlineDate(earliestPast); // past to mark expired
            index++;
        }

        log.info("📌 Applied expired scenario: totalExpired={}, withPlan={}, withoutPlan={}",
            expiredPlanSubset.size() + expiredNoPlanSubset.size(), expiredPlanSubset.size(), expiredNoPlanSubset.size());
    }
}
