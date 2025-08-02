package com.debtcollection.dto;

import org.springframework.data.domain.Page;
import org.springframework.hateoas.RepresentationModel;

import java.util.List;

/**
 * Generic wrapper for paginated responses with HATEOAS support.
 * 
 * @param <T> The type of content in the page
 */
public class PagedResponse<T> extends RepresentationModel<PagedResponse<T>> {
    
    private List<T> content;
    private PageMetadata page;
    
    public PagedResponse() {}
    
    public PagedResponse(Page<T> springPage) {
        this.content = springPage.getContent();
        this.page = new PageMetadata(
            springPage.getSize(),
            springPage.getNumber(),
            springPage.getTotalElements(),
            springPage.getTotalPages()
        );
    }
    
    public List<T> getContent() {
        return content;
    }
    
    public void setContent(List<T> content) {
        this.content = content;
    }
    
    public PageMetadata getPage() {
        return page;
    }
    
    public void setPage(PageMetadata page) {
        this.page = page;
    }
    
    /**
     * Page metadata information
     */
    public static class PageMetadata {
        private int size;
        private int number;
        private long totalElements;
        private int totalPages;
        
        public PageMetadata() {}
        
        public PageMetadata(int size, int number, long totalElements, int totalPages) {
            this.size = size;
            this.number = number;
            this.totalElements = totalElements;
            this.totalPages = totalPages;
        }
        
        public int getSize() {
            return size;
        }
        
        public void setSize(int size) {
            this.size = size;
        }
        
        public int getNumber() {
            return number;
        }
        
        public void setNumber(int number) {
            this.number = number;
        }
        
        public long getTotalElements() {
            return totalElements;
        }
        
        public void setTotalElements(long totalElements) {
            this.totalElements = totalElements;
        }
        
        public int getTotalPages() {
            return totalPages;
        }
        
        public void setTotalPages(int totalPages) {
            this.totalPages = totalPages;
        }
    }
}
