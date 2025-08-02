package com.debtcollection.repository;

import com.debtcollection.model.User;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

// USER PREFERENCE: Migrated from JpaRepository to MongoRepository
@Repository
public interface UserRepository extends MongoRepository<User, String> {

    // USER PREFERENCE: Spring Data MongoDB automatically provides query methods
    Optional<User> findByUsername(String username);
}
