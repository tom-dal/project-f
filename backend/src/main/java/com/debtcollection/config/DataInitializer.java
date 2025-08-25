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

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.UUID;

/**
 * USER PREFERENCE: Data initializer for MongoDB to replace data.sql functionality
 * Initializes test user and sample debt cases when application starts up
 */
@Component
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
        adminUser.setRoles(Set.of("ROLE_ADMIN", "ROLE_USER"));

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

        // CUSTOM IMPLEMENTATION: Create varied test cases covering all states and scenarios
        String[] debtorNames = {
            "Mario Rossi", "Giuseppe Verdi", "Anna Bianchi", "Francesco Neri", "Maria Gialli",
            "Luigi Ferrari", "Giovanna Romano", "Antonio Ricci", "Elena Conti", "Marco Russo",
            "Francesca Marino", "Roberto Costa", "Giulia Rizzo", "Andrea Fontana", "Paola Greco",
            "Davide Bruno", "Chiara Leone", "Stefano Galli", "Valentina Villa", "Matteo Barbieri",
            "Simona Colombo", "Federico Lombardi", "Alessia Martinelli", "Luca Santoro", "Serena Fiore",
            "Nicola Marchetti", "Cristina Pellegrini", "Daniele De Luca", "Michela Moretti", "Fabio Gatti"
        };

        CaseState[] states = CaseState.values();

        // Create 100 test cases with realistic distribution
        for (int i = 0; i < 100; i++) {
            DebtCase debtCase = new DebtCase();

            // Random debtor name
            String debtorName = debtorNames[random.nextInt(debtorNames.length)];
            if (i < debtorNames.length) {
                // First 30 cases use unique names
                debtCase.setDebtorName(debtorNames[i % debtorNames.length] + " " + (i + 1));
            } else {
                // Remaining cases can have duplicate names (realistic scenario)
                debtCase.setDebtorName(debtorName + " " + (char)('A' + random.nextInt(3)));
            }

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

            // Set next deadline based on state
            if (state != CaseState.COMPLETATA) {
                debtCase.setNextDeadlineDate(LocalDateTime.now().plusDays(random.nextInt(60) + 1));
            }

            // Installment plan generation (about 25% of cases)
            boolean createInstallmentPlan = random.nextDouble() < 0.25 && state != CaseState.COMPLETATA; // avoid COMPLETATA for simplicity
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
                    BigDecimal installmentAmount = (n == numberOfInstallments) ? total.subtract(accumulated) : base; // last catches remainder
                    if (installmentAmount.compareTo(BigDecimal.ZERO) <= 0) {
                        installmentAmount = BigDecimal.valueOf(1.00);
                    }
                    inst.setAmount(installmentAmount);
                    accumulated = accumulated.add(installmentAmount);
                    inst.setDueDate(LocalDateTime.now().plusMonths(n));
                    inst.setPaid(false); // leave unpaid to avoid needing payments
                    inst.setCreatedDate(LocalDateTime.now());
                    inst.setLastModifiedDate(LocalDateTime.now());
                    inst.setCreatedBy("system");
                    inst.setLastModifiedBy("system");
                    installments.add(inst);
                }
                debtCase.setInstallments(installments);
                debtCase.setHasInstallmentPlan(true); // CUSTOM IMPLEMENTATION: real installment plan present
            } else {
                debtCase.setHasInstallmentPlan(false);
            }

            // Random flags for variety (negotiations)
            debtCase.setOngoingNegotiations(random.nextBoolean() && random.nextDouble() < 0.3);
            // Paid flag: only mark COMPLETATA with true occasionally and leave installments logic separate
            boolean markPaid = state == CaseState.COMPLETATA && random.nextDouble() < 0.6; // 60% of completed cases
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

            // Add notes for some cases
            if (random.nextDouble() < 0.4) { // 40% of cases have notes
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

            // All cases are active by default
            debtCase.setActive(true);

            testCases.add(debtCase);
        }

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
}
