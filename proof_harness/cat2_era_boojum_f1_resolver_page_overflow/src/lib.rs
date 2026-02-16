#![allow(dead_code)]

/// Bug-parity model of `src/dag/resolver_box.rs` container paging logic.
///
/// This model preserves the critical behavior:
/// - allocate a new fixed-size page when current page does not fit `size`
/// - assume (without checking) that the new page is always large enough
/// - increment committed bytes by `size` without bounds check
struct Container {
    pages: Vec<ContainerPage>,
    cur_page_ix: usize,
    page_size: usize,
}

impl Container {
    fn new(size_power: usize) -> Self {
        let page_size = 1 << size_power;
        Self {
            pages: vec![ContainerPage::new(page_size)],
            cur_page_ix: 0,
            page_size,
        }
    }

    fn reserve(&mut self, size: usize) -> (usize, *mut u8) {
        let page = &mut self.pages[self.cur_page_ix];

        let page = match page.fits(size) {
            true => page,
            false => {
                // Bug parity: no guard for `size <= page_size`.
                self.pages.push(ContainerPage::new(self.page_size));
                self.cur_page_ix += 1;
                &mut self.pages[self.cur_page_ix]
            }
        };

        // Safety parity with source logic.
        unsafe { page.reserve(size) }
    }
}

#[derive(Debug)]
struct ContainerPage {
    allocation: Box<[u8]>,
    commited: usize,
}

impl ContainerPage {
    fn new(size: usize) -> Self {
        Self {
            allocation: vec![0u8; size].into_boxed_slice(),
            commited: 0,
        }
    }

    fn fits(&self, size: usize) -> bool {
        self.allocation.len() - self.commited >= size
    }

    unsafe fn reserve(&mut self, size: usize) -> (usize, *mut u8) {
        let loc = self.commited;
        self.commited += size;
        let ptr = self.allocation.as_mut_ptr().add(loc);
        (loc, ptr)
    }
}

#[cfg(test)]
mod tests {
    use super::Container;

    #[test]
    fn oversized_reservation_breaks_page_commit_invariant() {
        // Small page size to trigger condition with tiny test input.
        let mut container = Container::new(6); // page_size = 64

        // First request exceeds page size.
        let _ = container.reserve(128);

        let page = &container.pages[container.cur_page_ix];
        assert!(
            page.commited > page.allocation.len(),
            "expected committed bytes to exceed allocation length for oversized reservation"
        );
    }

    #[test]
    fn in_bound_reservation_preserves_invariant() {
        let mut container = Container::new(6); // page_size = 64
        let _ = container.reserve(32);
        let page = &container.pages[container.cur_page_ix];
        assert!(page.commited <= page.allocation.len());
    }
}
