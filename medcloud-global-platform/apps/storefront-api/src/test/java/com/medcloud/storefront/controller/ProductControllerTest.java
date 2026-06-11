package com.medcloud.storefront.controller;

import com.medcloud.storefront.model.Product;
import com.medcloud.storefront.service.ProductService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.bean.MockBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Unit tests for ProductController.
 */
@WebMvcTest(ProductController.class)
class ProductControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ProductService productService;

    private Product sampleProduct() {
        return Product.builder()
                .productId(UUID.randomUUID())
                .sku("MED-AMOX-500")
                .name("Amoxicillin 500mg")
                .category("antibiotics")
                .description("Broad-spectrum antibiotic")
                .price(new BigDecimal("12.99"))
                .currency("USD")
                .requiresPrescription(true)
                .stockQuantity(500)
                .build();
    }

    @Test
    @DisplayName("GET /api/v1/products — returns paginated product list")
    @WithMockUser
    void listProducts_returnsPage() throws Exception {
        Product product = sampleProduct();
        when(productService.findProducts(any(), any(), eq(false), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(product)));

        mockMvc.perform(get("/api/v1/products")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].sku").value("MED-AMOX-500"))
                .andExpect(jsonPath("$.content[0].name").value("Amoxicillin 500mg"))
                .andExpect(jsonPath("$.content[0].price").value(12.99));
    }

    @Test
    @DisplayName("GET /api/v1/products/{id} — returns single product")
    @WithMockUser
    void getProduct_found() throws Exception {
        Product product = sampleProduct();
        when(productService.findById(product.getProductId()))
                .thenReturn(Optional.of(product));

        mockMvc.perform(get("/api/v1/products/{id}", product.getProductId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sku").value("MED-AMOX-500"));
    }

    @Test
    @DisplayName("GET /api/v1/products/{id} — returns 404 for missing product")
    @WithMockUser
    void getProduct_notFound() throws Exception {
        UUID id = UUID.randomUUID();
        when(productService.findById(id)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/v1/products/{id}", id))
                .andExpect(status().isNotFound());
    }
}
