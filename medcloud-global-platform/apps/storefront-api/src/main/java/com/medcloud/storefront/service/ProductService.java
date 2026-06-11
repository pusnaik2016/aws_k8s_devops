package com.medcloud.storefront.service;

import com.medcloud.storefront.model.Product;
import com.medcloud.storefront.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

/**
 * Product business logic. Uses Redis caching (ElastiCache)
 * for frequently accessed catalog data.
 */
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class ProductService {

    private final ProductRepository productRepository;

    @Cacheable(value = "products", key = "#category + '-' + #search + '-' + #pageable.pageNumber")
    public Page<Product> findProducts(String category, String search,
                                       boolean prescriptionOnly, Pageable pageable) {
        if (category != null && search != null) {
            return productRepository.findByCategoryAndNameContainingIgnoreCase(category, search, pageable);
        } else if (category != null) {
            return productRepository.findByCategory(category, pageable);
        } else if (search != null) {
            return productRepository.findByNameContainingIgnoreCase(search, pageable);
        } else if (prescriptionOnly) {
            return productRepository.findByRequiresPrescription(true, pageable);
        }
        return productRepository.findAll(pageable);
    }

    @Cacheable(value = "product", key = "#productId")
    public Optional<Product> findById(UUID productId) {
        return productRepository.findById(productId);
    }

    @Transactional
    @CacheEvict(value = {"products", "product"}, allEntries = true)
    public Product createProduct(Product product) {
        log.info("Creating product: sku={}, name={}", product.getSku(), product.getName());
        return productRepository.save(product);
    }

    @Transactional
    @CacheEvict(value = {"products", "product"}, allEntries = true)
    public Optional<Product> updateProduct(UUID productId, Product updated) {
        return productRepository.findById(productId)
                .map(existing -> {
                    existing.setName(updated.getName());
                    existing.setCategory(updated.getCategory());
                    existing.setDescription(updated.getDescription());
                    existing.setPrice(updated.getPrice());
                    existing.setStockQuantity(updated.getStockQuantity());
                    existing.setRequiresPrescription(updated.isRequiresPrescription());
                    log.info("Updated product: id={}", productId);
                    return productRepository.save(existing);
                });
    }

    @Transactional
    @CacheEvict(value = {"products", "product"}, allEntries = true)
    public void deleteProduct(UUID productId) {
        productRepository.deleteById(productId);
        log.info("Deleted product: id={}", productId);
    }
}
