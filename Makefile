DIRECTORIES := $(patsubst %/,%,$(sort $(dir $(wildcard */*))))
TYPES := conf sys service
IMAGES := $(foreach dir,$(foreach type,$(TYPES),$(subst /,_,$(wildcard $(DIRECTORIES)/$(type)))),$(dir).erofs)

.PHONY: all $(DIRECTORIES) preqreqs clean
.SECONDEXPANSION:

# Build all images
all: $(DIRECTORIES)

# Build output directory for GitHub Actions
output: all
	mkdir output
	mv $(IMAGES) output/

# Build the erofs image
%.erofs: $$(shell find $$(subst _,/,%))
	$(eval $@_SOURCE := $(subst _,/,$(subst .erofs,,$@)))
	@echo "Making $@ with source $($@_SOURCE)"
	mkfs.erofs $@ $($@_SOURCE)

# Build all images related to service
$(DIRECTORIES): % : $(foreach type,$(TYPES),$(filter %_$(type).erofs, $(IMAGES)))

# Install prerequisites
preqreqs:
	apt install -y erofs-utils

# Clean up generated files
clean:
	rm -f *.erofs