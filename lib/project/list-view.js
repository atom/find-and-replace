const etch = require('etch');
const $ = require('../dom-helpers');
const resizeDetector = require('element-resize-detector')({strategy: 'scroll'});

module.exports = class ListView {
  constructor({items, heightForItem, itemComponent, className}) {
    this.items = items;
    this.heightForItem = heightForItem;
    this.itemComponent = itemComponent;
    this.className = className;
    etch.initialize(this);

    resizeDetector.listenTo(this.element, () => etch.update(this));
    this.element.addEventListener('scroll', () => etch.update(this));
  }

  update({items, heightForItem, itemComponent, className} = {}) {
    if (items) this.items = items;
    if (heightForItem) this.heightForItem = heightForItem;
    if (itemComponent) this.itemComponent = itemComponent;
    if (className) this.className = className;
    return etch.update(this)
  }

  render() {
    const children = [];
    let itemTopPosition = 0;

    if (this.element) {
      const {scrollTop, clientHeight} = this.element;
      const scrollBottom = scrollTop + clientHeight;

      let i = 0;

      for (; i < this.items.length; i++) {
        let itemBottomPosition = itemTopPosition + this.heightForItem(this.items[i], i);
        if (itemBottomPosition > scrollTop) break;
        itemTopPosition = itemBottomPosition;
      }

      for (; i < this.items.length; i++) {
        const item = this.items[i];
        const itemHeight = this.heightForItem(this.items[i], i);
        children.push(
          $.div(
            {
              style: {
                position: 'absolute',
                height: itemHeight + 'px',
                width: '100%',
                top: itemTopPosition + 'px'
              },
              key: i
            },
            $(this.itemComponent, {
              item: item,
              top: Math.max(0, scrollTop - itemTopPosition),
              bottom: Math.min(itemHeight, scrollBottom - itemTopPosition)
            })
          )
        );

        itemTopPosition += itemHeight;
        if (itemTopPosition >= scrollBottom) {
          i++
          break;
        }
      }

      for (; i < this.items.length; i++) {
        itemTopPosition += this.heightForItem(this.items[i], i);
      }
    }

    return $.div(
      {
        style: {
          position: 'relative',
          height: '100%',
          overflow: 'auto',
        }
      },
      $.ol(
        {
          ref: 'list',
          className: this.className,
          style: {height: itemTopPosition + 'px'}
        },
        ...children
      )
    );
  }
};
